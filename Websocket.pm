package Toyhouse::Websocket;
# WebSocket Service
#
# Connect to a websocket and perform main logic for order handling
use Data::Dumper;
use Time::HiRes qw/time/;
use Toyhouse::Model::Websocket::Subscription;
use Toyhouse::Signer;
use Toyhouse::Order;
use Toyhouse::Orderbooks;
use Toyhouse::Model::Order;
use Toyhouse::Coinbase::Request;
use Toyhouse::Coinbase::Private::Accounts;
use Toyhouse::Coinbase::MarketData::Products;
use Toyhouse::Coinbase::Private::Orders;
use Toyhouse::Model::Order::Metadata::Timer;
use Toyhouse::UUID;
use JSON qw/encode_json/;
use Mojo::Base qw/-strict -signatures/;
use Mojo::UserAgent;
use Mojo::mysql;
use Mojo::IOLoop;
use Mojo::Promise;
use Class::Struct( 'Toyhouse::Websocket' => {
	console			=> '$', #0, 1
	profile_name 	=> '$', # Alias for this websocket connection
	connect_count	=> '$', #This is for counting the connects before we receive ws data
	json_count		=> '$',

	uuid 			=> 'Toyhouse::UUID', # for generating client_oids
	channels		=> '@', #required
	product_ids		=> '@', #required

	storage			=> '$',
	dbh				=> 'Toyhouse::MariaDB',

	signer			=> 'Toyhouse::Signer',
	ua 				=> 'Mojo::UserAgent',

	request 		=> 'Toyhouse::Coinbase::Request',
	accounts 		=> 'Toyhouse::Coinbase::Private::Accounts',

	console_counter => '$',
	console_prod_loc=> '%',

	order_tracker 	=> '%',
	ticks 			=> '%',

	second_ago		=> '$',

	product_info 	=> '%',

	products 		=> 'Toyhouse::Coinbase::MarketData::Products',
	orders 			=> 'Toyhouse::Coinbase::Private::Orders',

	orderbook 		=> '%',

	bids			=> '%',
	asks			=> '%',

	order_details 	=> '%', # order_id => %order
	reorder_details => '%', # order_id => Toyhouse::Model::Order
	reorder_timer 		=> '%', # order_id => Toyhouse::Model::Metadata::Timer

	last_match	 	=> '%', # 'BTC-USD' => price # using track_order data for this

	base_re_pct		=> '%', #base 'filled', 'canceled' reorder percentage

	order_delay_sec	=> '$', #order delay in seconds

	too_far_percent => '$', # we don't want to move orders away that are this percentage away

});

$ENV{MOJO_CLIENT_DEBUG} =1; $| =1;
my $PROFILE = {};
our $ORDERBOOKS = Toyhouse::Orderbooks->new();
our $ORDERBOOK = {}; 
my $URL = 'wss://ws-feed.pro.coinbase.com';
my $UA = Mojo::UserAgent->new();

sub init($self) {
	die "profile_name required" unless $self->profile_name();
	die "profile_name already exists: ". $self->profile_name() if $PROFILE->{ $self->profile_name() };
	$self->display("\033[2J") if $self->console();
	$PROFILE->{ $self->profile_name() } = 1;

	$self->uuid( Toyhouse::UUID->new->build() );
	$self->signer( Toyhouse::Signer->new() ) unless $self->signer(); #signer is required even if credentials do not exist
	$self->request( Toyhouse::Coinbase::Request->new() )->build();
	$self->connect_count(0) unless $self->connect_count();
	$self->json_count(0);

	$self->base_re_pct( filled => 0.0075 );
	$self->base_re_pct( canceled => 0.0005 );
	$self->order_delay_sec(1800);
	$self->too_far_percent(0.01);

	$self->products(	Toyhouse::Coinbase::MarketData::Products->new( 	req => $self->request() ));
	$self->orders(		Toyhouse::Coinbase::Private::Orders->new( 		req => $self->request() ));

	$self->products->update_products();

	if ( $self->signer()->secret() ) {
		$self->request->signer( $self->signer() );
		$self->accounts( Toyhouse::Coinbase::Private::Accounts->new( req => $self->request()->build() )->build() );
		$self->accounts->update_accounts();
		$self->display_accounts_in_console();
		foreach my $product_id (@{ $self->product_ids() }) {
			$self->reorder_timer( $product_id => {} );
		}		
	}
	else {} # if we're subscribed to full, we shouldn't be authenticate to the websocket. Processing user_id are preferred on their own stream since we are actively processing each full message
	
	# allowing order tracking on user_id feed for now
	my $i = 0;
	foreach my $product_id (@{ $self->product_ids() }) {
		$self->order_tracker( $product_id => [[0]] );
		$self->console_prod_loc( $product_id => ($i+1) );
		$i++;
	}

	$self;
}

sub display_accounts_in_console($self) {
	return unless $self->console();
	my $row = 15;
	sub display_product_line ($self, $line, $product) {
		$product = uc $product;
		"\033[$line;0f\033[K  $product\033[$line;10f". $self->accounts->accounts->account($product)->available(). "\033[$line;35f". $self->accounts->accounts->account($product)->hold(). "\033[$line;60f". $self->accounts->accounts->account($product)->balance()
	}

	my $heading = "\033[$row;0f\033[KSYMBOL\033[$row;10fAVAILABLE TO TRADE\033[$row;35fON HOLD\033[$row;60fTOTAL BALANCE";
	my $console = $heading;
	$console .= $self->display_product_line(++$row, $_) foreach (USD => BTC => ETH => 'USDC');

	print STDOUT $console;

	my $done = {}; #no duplicates pls
	foreach (@{ $self->product_ids() }) {
		my ($product, $base) = split(/\-/, $_);
		next if $product =~ /BTC|USD/ || $done->{ $product };
		$row++;
		print STDOUT $self->display_product_line($row, $product);
		$done->{ $product } = 1;
	}
	print STDOUT "\n";
}

sub clean_quote($self, $product_id, $value) {
	return int($value / $self->products->product( $product_id )->{quote_increment}) * $self->products->product( $product_id )->{quote_increment};
}

sub clean_size($self, $product_id, $value) {
	return int($value / $self->products->product( $product_id )->{base_increment}) * $self->products->product( $product_id )->{base_increment};
}

sub minimum_size($self, $product_id) {
	return $self->products->product( $product_id )->{base_min_size};
}

sub display_historical_ticks_average_versus_order($self, $order) {
	return unless $self->console();
	my ($product_id, $price) = ($order->product_id(), $order->price());
	my ($line, $col) = ($self->console_prod_loc( $product_id ) > 63) ? ($self->console_prod_loc( $product_id ) - 63+1, 160) : ($self->console_prod_loc( $product_id )+1, 90);
	print STDOUT "\033[0;$col"."f\033[K". 
		"\033[0;". ($col +6) ."f".	"MARKET". 
		"\033[0;". ($col +18) ."f".	"TIME". 
		"\033[0;". ($col +27) ."f".	"SIZE". 
		"\033[0;". ($col +38) ."f".	"DIRECTION". 
		"\033[0;". ($col +48) ."f".	"PRICE". 
		"\033[0;". ($col +60) ."f".	"1MINAVG". 
		"\033[0;". ($col +60 +10 +2) ."f".	"15MINAVG". 
		"\033[0;". ($col +60 +20 +4) ."f".	"1HRAVG". 
		"\033[0;". ($col +60 +30 +6) ."f".	"2HRAVG". 
		"\033[0;". ($col +60 +40 +8) ."f".	"3HRAVG". 
		"\033[0;". ($col +60 +50 +10) ."f".	"1DAYAVG". 
		"\033[0;". ($col +60 +60 +12) ."f".	"7DAYAVG";

	print STDOUT
		"\033[$line;$col"."f\033[K" . 
		"\033[$line;". ($col +6) ."f". $product_id. 
		"\033[$line;". ($col +15) ."f". int( $order->time() ).
#						(($order->side() eq 'buy') ? "\033[0;31m" : "\033[1;32m"). #start color
		"\033[$line;". ($col +27) ."f". $self->clean_size($product_id, $order->size()).
		"\033[$line;". ($col +42) ."f". (($order->side() eq 'buy') ? 'v' : '^').
		"\033[$line;". ($col +48) ."f". $self->clean_quote($product_id, $price). 
#						"\033[0m". #end color
		"\033[$line;". ($col +60) ."f".			$self->is_greater_than_colorful( $self->get_avg_ticks($product_id => 1),	$price ) .
		"\033[$line;". ($col +60 +10 +2) ."f".	$self->is_greater_than_colorful( $self->get_avg_ticks($product_id => 15),	$price ) .
		"\033[$line;". ($col +60 +20 +4) ."f".	$self->is_greater_than_colorful( $self->get_avg_ticks($product_id => 60),	$price ) .
		"\033[$line;". ($col +60 +30 +6) ."f".	$self->is_greater_than_colorful( $self->get_avg_ticks($product_id => 120),	$price ) .
		"\033[$line;". ($col +60 +40 +8) ."f".	$self->is_greater_than_colorful( $self->get_avg_ticks($product_id => 180),	$price ) .
		"\033[$line;". ($col +60 +50 +10) ."f".	$self->is_greater_than_colorful( $self->get_avg_ticks($product_id => 1440),	$price ) .
		"\033[$line;". ($col +60 +60 +12) ."f".	$self->is_greater_than_colorful( $self->get_avg_ticks($product_id => 10080),$price );
}

sub display_order_in_console($self, $order) {
	unless ($self->console()) {
		$self->display(
			($order->order_id() || 
				($self->reorder_details($order->maker_order_id()) ? $order->maker_order_id() : $order->taker_order_id())), 
			$order->product_id(), 
			($order->reason() ? join(':', $order->type(), $order->reason()) : $order->type()), 
			$order->side(), 
			$order->price(), 
			($order->size() || 
				$order->remaining_size() || 
				(($self->reorder_details( $order->order_id() ) && 
					($self->reorder_details( $order->order_id() )->size() || 
					($self->reorder_details( $order->taker_order_id() ) && $self->reorder_details( $order->taker_order_id() )->size())  || 
					($self->reorder_details( $order->maker_order_id() ) && $self->reorder_details( $order->maker_order_id() )->size()) )))) || 
			"" );
		return
	}

	my $row = 1;
	print STDOUT "\033[$row;0f". " "x70;
	my $heading = "\033[$row;0fMARKET\033[$row;10fDATE\033[$row;35fPRICE\033[$row;60fSIZE";	
	print STDOUT $heading;
	$row++; print STDOUT "\033[$row;0f". " "x70; print STDOUT "\033[$row;0f". $order->product_id(). "\033[$row;10f". $order->time(). (($order->side() eq 'sell') ? "\033[0;31m" : "\033[1;32m"). "\033[$row;35f".$order->price().  "\033[$row;60f". ($order->size() || $order->remaining_size()) . "\033[0m";
}

sub track_order($self, $order, $type=60) { # type must be an int (size of the time bucket)
	my ($most_recent, $time, $low, $high, $open, $close, $volume) = (0, 0, 1, 2, 3, 4, 5);
	my $p = $self->order_tracker( $order->product_id() );

	$self->last_match( $order->product_id() => $order->price() );

	if ( ($p->[$most_recent]->[$time] + $type) > $order->time() ) {
		if ( $p->[$most_recent]->[$low] > $order->price() ) {
			$p->[$most_recent]->[$low] = $order->price()
		}
		elsif ( $p->[$most_recent]->[$high] < $order->price() ) {
			$p->[$most_recent]->[$high] = $order->price()
		}
	}
	else {
		unshift @$p, [ int( $order->time() ), $order->price(), $order->price(), $order->price() ]
	}

	$p->[$most_recent]->[$close] = $order->price();
	$p->[$most_recent]->[$volume] += $order->size();
}

sub get_avg_ticks_for_last_minutes($self, $product_id, $scope=1) { # returns the average price in range
	#base scope = 60
	my $ticks_in_scope = 60; #each bucket is 60 ticks 
	$scope *= $ticks_in_scope;
	my ($most_recent, $time, $low, $high, $open, $close, $volume) = (0, 0, 1, 2, 3, 4, 5);
	my $p = $self->order_tracker( $product_id );

	my $total = 0;
	my $i = 0;
 	
	unless ($p->[$i]->[$time]) { $self->log('get_avg_ticks_for_last_minutes() has not yet recorded any matches for', $product_id); return} # If we have no records, stop
	while ($p->[$i]->[$time] >= ($p->[$most_recent]->[$time] - $scope)) {
		$total += ( $p->[$i]->[$low] + $p->[$i]->[$high] );
		$i++;
	}

	my $result = $self->clean_quote($product_id, ( $total / ($i * 2) ));
	$self->log("get_avg_ticks_for_last_minutes($product_id, $scope)", $result);

	return $result
}

sub is_greater_than_colorful($self, $x, $y) {
	my $default = "\033[0m"; my $good = "\033[1;32m"; my $bad = "\033[0;31m";
	my $o = $default;
	if ($x < $y) { $o = $good } elsif ($x > $y ) { $o = $bad }
	$o .= $x . $default;
	$o;
}

sub update_product_order_book($self, $product_id) {
}

sub update_order($self, $order_id) {
	$self->orders->update_order( $order_id );
}

sub random_order_delay($int=60) {
	rand($int)
}

sub cancel_order_id($self, $order_id) {
	$self->log('canceled order id', $order_id) if $self->orders->cancel_order( $order_id );
}

sub remove_all_timers($self, $order_id=undef) { return unless $order_id;
	do {
		$self->log( 'removing all event timers for', $order_id );		
		$self->reorder_timer( $order_id )->remove_all_timers(); 
		delete $self->reorder_timer()->{ $order_id }
	} if $self->reorder_timer( $order_id );
}

sub remove_reorder_details($self, $order_id=undef) { return unless $order_id;
	do {
		$self->log( 'removing', $order_id, 'reorder details' );	
		delete $self->reorder_details()->{ $order_id } 
	} if $self->reorder_details( $order_id );
}

sub remove_order_details($self, $order_id=undef) {
	do {
		$self->log( 'removing', $order_id, 'order details' );
		delete $self->order_details()->{ $order_id } 
	} if $self->order_details( $order_id );
}

sub cleanup($self, $order_id = undef) { return unless $order_id;
	$self->remove_all_timers( $order_id );
	$self->remove_order_details( $order_id );
	$self->remove_reorder_details( $order_id );
}

sub process_user_id_received_message($self, $order=undef) { return unless $order->client_oid(); # currently not handling orders that don't have a client_oid
	$self->cleanup( $order->client_oid() ); # client_oid is used to track orders that we've placed.

	# stores data used to calculate place_new_order() details
	my $average_price_last_5_minutes = sub { $self->get_avg_ticks_for_last_minutes( $order->product_id(), 5 ) || $self->base_re_pct() };
	my $percent_from_price_to_last_match = sub { my $most_recent_match_price = $self->last_match( $order->product_id() ); abs($most_recent_match_price - $order->price())/$most_recent_match_price if $most_recent_match_price };
	my $order_delay_in_secs = $self->order_delay_sec();

	$self->order_details( $order->order_id() => { type => $order->type(), remaining_size => $order->size(), percent_from_price_to_last_match => $percent_from_price_to_last_match, move_direction => 1, move_rate => 1 , order_delay_in_secs => $order_delay_in_secs } );

	# The following must exist in order for us to work with it
	$self->reorder_details( $order->order_id() => Toyhouse::Model::Order->new( product_id => $order->product_id(), size => $order->size(), side => $order->side() )->build() ); 

	# we handle order_id first because client_oid is only on received messages
	$self->reorder_timer( $order->order_id() => Toyhouse::Model::Order::Metadata::Timer->new->build() );
	$self->log("client_oid:", $order->client_oid(), "= order_id:", $order->order_id()); # for visibility	
}

sub process_user_id_open_message($self, $order=undef) {
	return unless $self->reorder_details( $order->order_id() );
	my $distance = $self->order_details( $order->order_id() )->{percent_from_price_to_last_match}->();
	my $move_rate = \$self->order_details( $order->order_id() )->{move_rate};
	my $move_direction = \$self->order_details( $order->order_id() )->{move_direction};
	my $move_delay = \$self->order_details( $order->order_id() )->{order_delay_in_secs};

	if ( $order->remaining_size() < $self->products->product( $order->product_id() )->{base_min_size} ) {
		$self->log( 'failing to set cancel timer event, remaining_size is too small:', $order->remaining_size() );
		$self->cleanup( $order->order_id() );
	}
	elsif ($distance) { #This probably be done elsewhere so filled orders can also take advantage
		if ($distance < ($self->too_far_percent()/5)) {
			$$move_delay = ($$move_delay / $$move_delay) / 5;
			$$move_rate = 1/3;
			$self->log( 'order_id', $order->order_id(), 'move rate decreased by:', $$move_rate, 'distance:', $distance, 'direction' => $$move_direction, 'move_delay: ', $$move_delay );
		}
		elsif ($distance < ($self->too_far_percent()/3)) {
			$$move_delay = ($$move_delay / $$move_delay) / 3;				
			$$move_rate = 1/3;
			$self->log( 'order_id', $order->order_id(), 'move rate decreased by:', $$move_rate, 'distance:', $distance, 'direction' => $$move_direction, 'move_delay: ', $$move_delay );
		}			
		elsif ($distance < ($self->too_far_percent()/2)) {
			$$move_delay = ($$move_delay / $$move_delay) / 2;				
			$$move_rate = 1/2;
			$self->log( 'order_id', $order->order_id(), 'move rate decreased by:', $$move_rate, 'distance:', $distance, 'direction' => $$move_direction, 'move_delay: ', $$move_delay );
		}
		elsif ($distance < $self->too_far_percent()) {
			$$move_delay = ($$move_delay / $$move_delay);
			$self->log( $order->order_id(), 'has expired and is', $distance, 'from last match' );
			$self->cancel_order_id( $order->order_id() )
		}			
		elsif ($distance < ($self->too_far_percent() *2)) {
			$$move_delay = $$move_delay * 1;
			$$move_rate = 1/2;
			$self->log( 'order_id', $order->order_id(), 'move rate decreased by:', $$move_rate, 'distance:', $distance, 'direction' => $$move_direction, 'move_delay: ', $$move_delay );
		}
		elsif ($distance < ($self->too_far_percent() *3)) {
			$$move_delay = $$move_delay * 2;
			$$move_rate = 1/3;
			$self->log( 'order_id', $order->order_id(), 'move rate decreased by:', $$move_rate, 'distance:', $distance, 'direction' => $$move_direction, 'move_delay: ', $$move_delay );
		}		
		elsif ($distance < ($self->too_far_percent() *5)) {
			$$move_delay = $$move_delay * 3;			
			$$move_rate = 1/5;				
			$self->log( 'order_id', $order->order_id(), 'move rate decreased by:', $$move_rate, 'distance:', $distance, 'direction' => $$move_direction, 'move_delay: ', $$move_delay );
		}
		elsif ($distance < ($self->too_far_percent() *8)) {
			$$move_delay = $$move_delay * 5;
			$$move_rate = 1/5;			
			$$move_direction = -1;
			$self->log( 'order_id', $order->order_id(), 'move rate decreased by:', $$move_rate, 'distance:', $distance, 'direction' => $$move_direction, 'move_delay: ', $$move_delay );
		}
		elsif ($distance < ($self->too_far_percent() *13)) {
			$$move_delay = $$move_delay * 8;			
			$$move_rate = 1/3;			
			$$move_direction = -1;
			$self->log( 'order_id', $order->order_id(), 'move rate decreased by:', $$move_rate, 'distance:', $distance, 'direction' => $$move_direction, 'move_delay: ', $$move_delay );
		}
		elsif ($distance < ($self->too_far_percent() *21)) {
			$$move_delay = $$move_delay * 13;			
			$$move_rate = 1/2;
			$$move_direction = -1;
			$self->log( 'order_id', $order->order_id(), 'move rate decreased by:', $$move_rate, 'distance:', $distance, 'direction' => $$move_direction, 'move_delay: ', $$move_delay );
		}
		elsif ($distance < ($self->too_far_percent() *34)) {
			$$move_delay = $$move_delay * 21;			
			$$move_rate = 1;
			$$move_direction = -1;
			$self->log( 'order_id', $order->order_id(), 'move rate decreased by:', $$move_rate, 'distance:', $distance, 'direction' => $$move_direction, 'move_delay: ', $$move_delay );
		}
		elsif ($distance < ($self->too_far_percent() *55)) {
			$$move_delay = $$move_delay * 34;			
			$$move_rate = 1;
			$$move_direction = -1;
			$self->log( 'order_id', $order->order_id(), 'move rate decreased by:', $$move_rate, 'distance:', $distance, 'direction' => $$move_direction, 'move_delay: ', $$move_delay );
		}
		else {
			$self->log( 'order_id', $order->order_id(), 'is too far:', ($distance || 'undefined'), 'not setting cancel event timer' );
			return;
		}
		$self->log( 'setting order_id', $order->order_id(), 'cancel timer for', $self->reorder_timer( $order->order_id() )->open( $$move_delay ), 'seconds' );
		$self->reorder_timer( $order->order_id() )->start_timer(open => sub { $self->cancel_order_id( $order->order_id() ) })
	}
}

sub process_user_id_match_message($self, $order=undef) {
	my $order_id;
	if ($self->order_details( $order->taker_order_id() )) { # there are no timers to remove
		$self->log( $order->taker_order_id(), 'is a taker match' ); 
		$order_id = $order->taker_order_id() 
	}
	elsif ($self->order_details( $order->maker_order_id() )) {
		$self->remove_all_timers( $order->maker_order_id() ); 
		$order_id = $order->maker_order_id();
	}
	else {
		return # must be a market order or we haven't gotten a receive message
	}

	$self->order_details( $order_id )->{remaining_size} += -$order->size();
	$self->dbh->record( $order->to_json() ) if $self->dbh(); 	
}

sub process_user_id_done_message($self, $order=undef) {
	# make sure reorder_details exists or return
	if (!$self->reorder_details( $order->order_id() )) { 
		# We can work with a done message if the order has a remaining_size that is minimum_size or greater, 
		# otherwise we will return because we need reorder_details.
		return $self->cleanup( $order->order_id() ) unless $order->remaining_size() && ($order->remaining_size() >= $self->minimum_size( $order->product_id() )); 

		# setup a new reorder_details
		$self->reorder_details( $order->order_id() => Toyhouse::Model::Order->new( product_id => $order->product_id(), size => $order->remaining_size() )->build() )
	}

	# event timers are no longer exist for this order id since we're processing it. If event timers are needed, we'll create them.
	$self->remove_all_timers( $order->order_id() ) if $self->reorder_timer( $order->order_id() );

	# change message can cause remaining_size to be 0 on canceled message? (currently not handled)
	my ($new_side, $new_price, $new_size, $order_delay_secs) = ('buy', 0, $order->remaining_size(), random_order_delay($self->order_delay_sec()));

	my $price_move_amount = 0;

	if ($order->reason() eq 'filled') {
		$price_move_amount = $order->price() *(rand($self->base_re_pct( 'filled' )) +$self->base_re_pct( 'filled' ));
		$new_side = 'sell' if $order->side eq 'buy';
		#$order_delay_secs *= $self->order_delay_sec();
		$new_size = $self->reorder_details( $order->order_id() )->size(); #because we're filled, we must use size from the received message
	}
	else {
		my ($custom_move_rate_modifier,$custom_direction_modifier);
		$price_move_amount = $order->price() *(rand($self->base_re_pct( 'canceled' )) +$self->base_re_pct( 'canceled' ));
		$new_side = 'sell' if $order->side eq 'sell';

		if ($self->order_details( $order->order_id() )) {
			($custom_move_rate_modifier,$custom_direction_modifier) = ($self->order_details( $order->order_id() )->{move_rate}, $self->order_details( $order->order_id() )->{move_direction});
			$price_move_amount *= $custom_move_rate_modifier;		
			$price_move_amount *= $custom_direction_modifier;
		}

	}
	
	# The new price that will be placed once the order is executed.
	$new_price = ($new_side eq 'sell') ? $self->clean_quote($order->product_id(), ($order->price() +$price_move_amount)) : $self->clean_quote($order->product_id(), ($order->price() -$price_move_amount));

	$self->reorder_details( $order->order_id() )->price( $new_price );
	$self->reorder_details( $order->order_id() )->side( $new_side );
	$self->reorder_details( $order->order_id() )->client_oid( $self->uuid->generate( $order->order_id() ) );

	$order_delay_secs = $self->order_details( $order->order_id() )->{order_delay_in_secs} if $self->order_details( $order->order_id() );
	$self->reorder_timer( $self->reorder_details( $order->order_id() )->client_oid() => Toyhouse::Model::Order::Metadata::Timer->new( filled => 0.1 )->build() ); # testing # $order_delay_secs
	$self->log( $self->reorder_timer( $self->reorder_details( $order->order_id() )->client_oid() )->filled(), 'sec place_order delay for order_id:', $order->order_id(), '=> client_oid:', $self->reorder_details( $order->order_id() )->client_oid() );
	$self->reorder_timer( $self->reorder_details( $order->order_id() )->client_oid() )->start_timer( filled => sub {

		$self->log( 'executing order client_oid:', $self->reorder_details( $order->order_id() )->client_oid() ); 

		$self->orders->place_new_order({
			client_oid	=> $self->reorder_details( $order->order_id() )->client_oid(),
			product_id	=> $self->reorder_details( $order->order_id() )->product_id(), 
			side		=> $self->reorder_details( $order->order_id() )->side(),
			size		=> $self->reorder_details( $order->order_id() )->size(),
			price		=> $self->reorder_details( $order->order_id() )->price()});

		$self->cleanup( $order->order_id() );
	});						
}

sub start($self) {
	$UA->websocket_p($URL)->then(sub ($tx) {
		$self->profile_name( 'I am' ) unless $self->profile_name();

		my $promise = Mojo::Promise->new();
		$self->display( ($self->console() ? "\033[K\033[75;0f" : ""), "connecting." );

		$tx->on(json => sub ($tx, $order) { return unless $order->{product_id}; $order = Toyhouse::Model::Order->new( %$order )->build();
			return if $order->type() eq 'received' && !$order->user_id();

			$self->connect_count(0) if $self->connect_count(); $self->json_count($self->json_count() +1);

			if ( $order->user_id() ) {
				return if $order->type() eq 'change'; #not handling this right now
				$self->accounts->update_accounts();						
				return unless $order->price(); #market orders are currently not welcome

				$self->display_order_in_console( $order );
				$self->display_accounts_in_console();

				if ($order->type() eq 'received') { $self->process_user_id_received_message($order) }
				elsif ($order->type() eq 'open') { $self->process_user_id_open_message($order) }
				elsif ($order->type() eq 'done') { $self->process_user_id_done_message($order) }					
				elsif ( $order->type eq 'match' ) { $self->process_user_id_match_message($order) }
 			}
 			else {
 				if ($order->type() eq 'match') {
					$self->track_order($order);
					if ($self->dbh) {
						#only record minimal data;
						# we set the product_id so it will be appended to the table_name we are writing to. 						
						$self->dbh->product_id( $order->product_id() );
	 					# write the data to the $table_name_$product_id
						$self->dbh->record( Toyhouse::Model::Order->new(
							price		=> $order->price(),
							product_id	=> $order->product_id(),
							side		=> $order->side(),
							size		=> $order->size(),
							time		=> $order->time())->build->to_json());
					}
				}
			}
		});

		$tx->on(finish => sub { $self->display( ($self->console() ? "\033[K\033[75;0f" : ""), "disconnected" ); $self->start() }); #sub promise { this is a promise  that never ends, yes it goes on and on my friend.. some people started running it not knowing what it was, and they continue running it forever just because... promise()

		$tx->send( 
			$self->signer->sign_ws_subscription(
				Toyhouse::Model::Websocket::Subscription->new(
					type => 'subscribe',
					channels => $self->channels,
					product_ids => $self->product_ids)
				->payload()
			)
		);

		return $promise;

	})->catch(sub ($err) {
		$self->log( "WebSocket error: $err" );
	});
}

sub log ($self, @message) { print STDERR join(" ", time(), $self->profile_name(), @message, "\n") }
sub display ($self, @message) { print STDOUT join(" ", time(), $self->profile_name(), @message, "\n") }