package Toyhouse::Websocket;
# WebSocket Service
#
# Connect to a websocket and then record matches to db.
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
	reorders 		=> '%', # BTC-USD => order_id

	last_match	 	=> '%', # 'BTC-USD' => price

	base_re_pct		=> '%', #base 'filled', 'canceled' reorder percentage

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

	$self->base_re_pct( filled => 0.01 );
	$self->base_re_pct( canceled => 0.001 );

	$self->products(	Toyhouse::Coinbase::MarketData::Products->new( 	req => $self->request() ));
	$self->orders(		Toyhouse::Coinbase::Private::Orders->new( 		req => $self->request() ));

	$self->products->update_products();

	if ( $self->signer()->secret() ) {
		$self->request->signer( $self->signer() );
		$self->accounts( Toyhouse::Coinbase::Private::Accounts->new( req => $self->request()->build() )->build() );
		$self->accounts->update_accounts();
		$self->display_accounts_in_console();
		foreach my $product_id (@{ $self->product_ids() }) {
			$self->reorders( $product_id => {} );
		}		
	}
	else { # if we're subscribed to full, we shouldn't be authenticate to the websocket. Processing user_id are preferred on their own stream since we are actively processing each full message
		my $i = 0;
		foreach my $product_id (@{ $self->product_ids() }) {
			$self->order_tracker( $product_id => [[0]] );
			$self->console_prod_loc( $product_id => ($i+1) );
			$i++;
		}
		#$self->console_counter(0); # not used
	}

#	Mojo::IOLoop->singleton->reactor->timer(2 => sub {  });
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
	my ($line, $col) = ($self->console_prod_loc( $order->product_id() ) > 63) ? ($self->console_prod_loc( $order->product_id() ) - 63+1, 160) : ($self->console_prod_loc( $order->product_id() )+1, 90);
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
		"\033[$line;". ($col +6) ."f". $order->product_id(). 
		"\033[$line;". ($col +15) ."f". int( $order->time() ).
#						(($order->side() eq 'buy') ? "\033[0;31m" : "\033[1;32m"). #start color
		"\033[$line;". ($col +27) ."f". $self->clean_size($order->product_id(), $order->size()).
		"\033[$line;". ($col +42) ."f". (($order->side() eq 'buy') ? 'v' : '^').
		"\033[$line;". ($col +48) ."f". $self->clean_quote($order->product_id(), $order->price()). 
#						"\033[0m". #end color
		"\033[$line;". ($col +60) ."f".			$self->is_greater_than_colorful( $self->get_avg_ticks($order => 1),		$order->price() ) .
		"\033[$line;". ($col +60 +10 +2) ."f".	$self->is_greater_than_colorful( $self->get_avg_ticks($order => 15),	$order->price() ) .
		"\033[$line;". ($col +60 +20 +4) ."f".	$self->is_greater_than_colorful( $self->get_avg_ticks($order => 60),	$order->price() ) .
		"\033[$line;". ($col +60 +30 +6) ."f".	$self->is_greater_than_colorful( $self->get_avg_ticks($order => 120),	$order->price() ) .
		"\033[$line;". ($col +60 +40 +8) ."f".	$self->is_greater_than_colorful( $self->get_avg_ticks($order => 180),	$order->price() ) .
		"\033[$line;". ($col +60 +50 +10) ."f".	$self->is_greater_than_colorful( $self->get_avg_ticks($order => 1440),	$order->price() ) .
		"\033[$line;". ($col +60 +60 +12) ."f".	$self->is_greater_than_colorful( $self->get_avg_ticks($order => 10080),	$order->price() );
}

sub display_order_in_console($self, $order) {
	unless ($self->console()) {
		$self->display( $order->time(), 
			($order->order_id() || 
				($self->order_details($order->maker_order_id()) ? $order->maker_order_id() : $order->taker_order_id())), 
			$order->product_id(), 
			($order->reason() ? join(':', $order->type(), $order->reason()) : $order->type()), 
			$order->side(), 
			$order->price(), 
			($order->size() || 
				$order->remaining_size() || 
				(($self->order_details( $order->order_id() ) && 
					($self->order_details( $order->order_id() )->remaining_size() || 
					($self->order_details( $order->taker_order_id() ) && $self->order_details( $order->taker_order_id() )->remaining_size())  || 
					($self->order_details( $order->maker_order_id() ) && $self->order_details( $order->maker_order_id() )->remaining_size()) )))) || 
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

sub get_avg_ticks($self, $order, $scope=1) { #base scope = 60
	my $ticks_in_scope = 60; #each bucket is 60 ticks 
	$scope *= $ticks_in_scope;
	my ($most_recent, $time, $low, $high, $open, $close, $volume) = (0, 0, 1, 2, 3, 4, 5);
	my $p = $self->order_tracker( $order->product_id() );

	my $avg = 0;
	my $i = 0;
	while ($p->[$i]->[$time] >= ($p->[$most_recent]->[$time] - $scope)) {
		$avg += ( $p->[$i]->[$low] + $p->[$i]->[$high] );
		$i++;
	}

	return $self->clean_quote($order->product_id(), ( $avg / ($i * 2) ));
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

				if ($order->type() eq 'received') {
					$self->order_details( $order->order_id() => $order );
					$self->order_details( $order->order_id() )->remaining_size( $order->size() );
					$self->reorders( $order->product_id() )->{ $order->order_id() } = [];
					push @{ $self->reorders( $order->product_id() )->{ $order->order_id() } }, $self->reorders( $order->product_id() )->{ $order->client_oid() } if $self->reorders( $order->product_id() )->{ $order->client_oid() };
				}
				elsif ($order->type() eq 'open') {
					$self->order_details( $order->order_id() )->remaining_size( $order->remaining_size() );
					$self->order_details( $order->order_id() )->{type} = $order->type();
					#order tests
					#push @{ $self->reorders( $order->product_id() )->{ $order->order_id() } }, Mojo::IOLoop->singleton->reactor->recurring(2 => sub { use Data::Dumper; print STDERR Dumper $order; print STDERR $self->last_match( $order->product_id ) if $self->last_match( $order->product_id ) } )
				}
				elsif ($order->type() eq 'done') {

					#remove all evnts for this order_id
					if ($self->reorders( $order->product_id() )->{ $order->order_id() }) { Mojo::IOLoop->remove( $_ ) foreach @{ $self->reorders( $order->product_id() )->{ $order->order_id() } } }

					return $self->display($self->profile_name(), 'proper size not listed for', $order->order_id()) # This actually doesn't return anything but outputs a message to STDERR, don't be fooled
						unless (($self->order_details( $order->order_id() ) && ($self->order_details( $order->order_id() )->remaining_size() || $self->order_details( $order->order_id() )->size())) || ($order->remaining_size() >= $self->minimum_size( $order->product_id() )) );

					my $new_order = Toyhouse::Model::Order->new();	
					my ($new_side, $new_price, $order_delay) = ('buy', 0, 60);

 					if ($order->reason() eq 'filled') {
 						$new_price = $order->price() * $self->base_re_pct( 'filled' );
 						$new_side = 'sell' if $order->side eq 'buy';
 						$order_delay *= 60 * 3; 
					}
					else {
						$new_price = $order->price() * $self->base_re_pct( 'canceled' );
						$new_side = 'sell' if $order->side eq 'sell';
					}

					$new_price = ($new_side eq 'sell') ? $self->clean_quote($order->product_id(), ($order->price() + $new_price)) : $self->clean_quote($order->product_id(), ($order->price() - $new_price));

					$new_order->price( $new_price );
					$new_order->side( $new_side );
					$new_order->product_id($order->product_id());
					$new_order->size( ($order->remaining_size() || ($self->order_details( $order->order_id() )->remaining_size() || $self->order_details( $order->order_id() )->size())) );
					$new_order->client_oid( $self->uuid->generate() );

					$self->log($self->profile_name(), $order_delay, 'sec order delay for', $new_order->client_oid());

					$self->reorders( $order->product_id() )->{ $new_order->client_oid() } = Mojo::IOLoop->singleton->reactor->timer($order_delay => sub { $self->log('executing order', $new_order->client_oid()); $self->orders->place_new_order( $new_order->build()->no_class() ) });
					
					# clean up $order->order_id()
					delete $self->order_details()->{$order->order_id()} if $self->order_details( $order->order_id() );
 				}					
				elsif ( $order->type eq 'match') {
					if ( $self->order_details( $order->maker_order_id() ) ) { $self->order_details( $order->maker_order_id() )->remaining_size( $self->order_details( $order->maker_order_id() )->remaining_size() - $order->size() )}
					elsif ( $self->order_details( $order->taker_order_id() ) ) { $self->order_details( $order->taker_order_id() )->remaining_size( $self->order_details( $order->taker_order_id() )->remaining_size() - $order->size() )}
					$self->dbh->record( $order->to_json() ) if $self->dbh();
				}
 			}
 			else {#if ( !$self->signer->secret() ) { # If no secret exists, this is used for 'general' 
 				if ($order->type() eq 'match') {
 					$self->track_order($order);
#					Mojo::IOLoop->singleton->reactor->timer(2 => sub { undef $self->{update_ticks_display} });
					# $self->display_historical_ticks_average_versus_order($order);
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