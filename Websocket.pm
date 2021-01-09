package Toyhouse::Websocket;
# WebSocket Service
#
# Connect to a websocket and then record matches to db.
use Toyhouse::Model::Websocket::Subscription;
use Toyhouse::Signer;
use Toyhouse::Order;
use Toyhouse::Orderbooks;
use Toyhouse::Model::Order;
use Toyhouse::Coinbase::Request;
use Toyhouse::Coinbase::Private::Accounts;
use Toyhouse::Coinbase::MarketData::Products;
use JSON qw/encode_json/;
use Mojo::Base qw/-strict -signatures/;
use Mojo::UserAgent;

use Mojo::mysql;
use Mojo::Promise;
use Class::Struct( 'Toyhouse::Websocket' => {
	profile_name 	=> '$', # Alias for this websocket connection
	connect_count	=> '$', #This is for counting the connects before we receive ws data
	json_count		=> '$',

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
	second_ago		=> '$',

	product_info 	=> '%',

	products 		=> 'Toyhouse::Coinbase::MarketData::Products',
});

$ENV{MOJO_CLIENT_DEBUG} =1; $| =1;
my $PROFILE = {};
our $ORDERBOOKS = Toyhouse::Orderbooks->new();
my $URL = 'wss://ws-feed.pro.coinbase.com';
my $UA = Mojo::UserAgent->new();

sub init($self) {
	die "profile_name required" unless $self->profile_name();
	die "profile_name already exists: ". $self->profile_name() if $PROFILE->{ $self->profile_name() };
	print STDERR "\033[2J";
	$PROFILE->{ $self->profile_name() } = 1;

	$self->signer( Toyhouse::Signer->new() ) unless $self->signer(); #signer is required even if credentials do not exist
	$self->request( Toyhouse::Coinbase::Request->new() )->build();
	$self->connect_count(0) unless $self->connect_count();
	$self->json_count(0);

	$self->products(Toyhouse::Coinbase::MarketData::Products->new( req => $self->request() ));

	$self->products->update_products();

	my $i = 0;
	foreach (@{ $self->product_ids() }) {
		$self->order_tracker( $_ => [[0]] );
		$self->console_prod_loc( $_ => ($i+1) );
		$i++;
	}

	if ( $self->signer()->secret() ) {
		$self->request->signer( $self->signer() );
		$self->accounts( Toyhouse::Coinbase::Private::Accounts->new( req => $self->request()->build() )->build() );
		$self->accounts->update_accounts();
		$self->display_accounts_in_console();
	}
	$self->console_counter(0);
	$self;
}

sub display_accounts_in_console($self) {
	my $row = 15;
	sub display_product_line ($self, $line, $product) {
		$product = uc $product;
		"\033[$line;0f\033[K  $product\033[$line;10f". $self->accounts->accounts->account($product)->available(). "\033[$line;35f". $self->accounts->accounts->account($product)->hold(). "\033[$line;60f". $self->accounts->accounts->account($product)->balance()
	}

	my $heading = "\033[$row;0f\033[KSYMBOL\033[$row;10fAVAILABLE TO TRADE\033[$row;35fON HOLD\033[$row;60fTOTAL BALANCE";
	my $console = $heading;
	$console .= $self->display_product_line(++$row, $_) foreach (USD => BTC => ETH => 'USDC');

	print STDERR $console;

	my $done = {}; #no duplicates pls
	foreach (@{ $self->product_ids() }) {
		my ($product, $base) = split(/\-/, $_);
		next if $product =~ /BTC|USD/ || $done->{ $product };
		$row++;
		print STDERR $self->display_product_line($row, $product);
		$done->{ $product } = 1;
	}
	print STDERR "\n";
}

sub clean_quote($self, $product_id, $value) {
	return int($value / $self->products->product( $product_id )->{quote_increment}) * $self->products->product( $product_id )->{quote_increment};
}

sub clean_size($self, $product_id, $value) {
	return int($value / $self->products->product( $product_id )->{base_increment}) * $self->products->product( $product_id )->{base_increment};
}

sub display_match_in_console($self, $order) {
	my $row = 1;
	my $heading = "\033[$row;0f\033[KMARKET\033[$row;10fDATE\033[$row;35fPRICE\033[$row;60fSIZE";	
	print STDERR $heading;
	$row++; print STDERR "\033[$row;0f\033[K". $order->product_id(). "\033[$row;10f". $order->time(). (($order->side() eq 'sell') ? "\033[0;31m" : "\033[1;32m"). "\033[$row;35f".$order->price().  "\033[$row;60f". ($order->size() || $order->remaining_size()) . "\033[0m";
}

sub track_order($self, $order, $type=60) { # type must be an int (size of the time bucket)
	my ($most_recent, $time, $low, $high, $open, $close, $volume) = (0, 0, 1, 2, 3, 4, 5);
	my $p = $self->order_tracker( $order->product_id() );

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

sub start($self) {
	$UA->websocket_p($URL)->then(sub ($tx) {
		$self->profile_name( 'I am' ) unless $self->profile_name();

		my $promise = Mojo::Promise->new();
		print STDERR "\033[K\033[75;0fconnecting...";

		$tx->on(json => sub ($tx, $order) { $order = Toyhouse::Model::Order->new( %$order )->build();
			return unless $order->product_id();

			$self->connect_count(0); $self->json_count($self->json_count() +1);

			if ( $order->user_id() ) {
				if ( $order->type() ne 'received' ) {
					$self->accounts->update_accounts();						
					$self->display_match_in_console( $order );
					$self->display_accounts_in_console();					
					if ( $order->type eq 'match') {
						$self->dbh->record( $order->to_json() ) if $self->dbh();
					}
					
				}
 			}
 			elsif ( !$self->signer->secret() ) { # If no secret exists, this is used for 'general' 
 				if ($order->type() eq 'match') {
 					$self->track_order($order);
 					my ($line, $col) = ($self->console_prod_loc( $order->product_id() ) > 63) ? ($self->console_prod_loc( $order->product_id() ) - 63+1, 160) : ($self->console_prod_loc( $order->product_id() )+1, 90);
 					$self->log("\033[0;$col"."f\033[K". 
 						"\033[0;". ($col) ."fMARKET". 
 						"\033[0;". ($col +15) ."fTIME". 
 						"\033[0;". ($col +27) ."fSIZE". 
 						"\033[0;". ($col +36) ."fDIRECTION". 
 						"\033[0;". ($col +48) ."fPRICE". 
 						"\033[0;". ($col +60) ."fMIN". 
 						"\033[0;". ($col +60 +10) ."f15MIN". 
 						"\033[0;". ($col +60 +20) ."f1HR". 
 						"\033[0;". ($col +60 +30) ."f2HR". 
 						"\033[0;". ($col +60 +40) ."f3HR". 
 						"\033[0;". ($col +60 +50) ."fDAY". 
 						"\033[0;". ($col +60 +60) ."f7DAY");

					$self->log( 
						"\033[$line;$col"."f\033[K" . $order->product_id(). 
						"\033[$line;". ($col +9) ."f". $order->time().
						(($order->side() eq 'buy') ? "\033[0;31m" : "\033[1;32m"). #start color
						"\033[$line;". ($col +27) ."f". $self->clean_size($order->product_id(), $order->size()).
						"\033[$line;". ($col +40) ."f". (($order->side() eq 'buy') ? 'v' : '^').
						"\033[$line;". ($col +48) ."f". $self->clean_quote($order->product_id(), $order->price()). 
						"\033[0m". #end color
						"\033[$line;". ($col +60) ."f". $self->get_avg_ticks($order => 1).
						"\033[$line;". ($col +60 +10) ."f". $self->get_avg_ticks($order => 15). 
						"\033[$line;". ($col +60 +20) ."f". $self->get_avg_ticks($order => 60).
						"\033[$line;". ($col +60 +30) ."f". $self->get_avg_ticks($order => 120).						
						"\033[$line;". ($col +60 +40) ."f". $self->get_avg_ticks($order => 180).
						"\033[$line;". ($col +60 +50) ."f". $self->get_avg_ticks($order => 1440).
						"\033[$line;". ($col +60 +60) ."f". $self->get_avg_ticks($order => 10080));

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

		$tx->on(finish => sub { print STDERR "\033[K\033[75;0fdisconnected"; $self->start() }); #sub promise { this is a promise  that never ends, yes it goes on and on my friend.. some people started running it not knowing what it was, and they continue running it forever just because... promise()

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

sub log ($self, @message) { say join(" ", @message) }