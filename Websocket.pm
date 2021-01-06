package Toyhouse::Websocket;
# WebSocket Service
#
# Connect to a websocket and then record matches to db.
use Toyhouse::Model::Websocket::Subscription;
use Toyhouse::Signer;
use Toyhouse::Order;
use Toyhouse::Orderbooks;
use Toyhouse::Model::Order;
use Mojo::UserAgent;

use JSON qw/encode_json/;
use Mojo::Base qw/-strict -signatures/;
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
});

$ENV{MOJO_CLIENT_DEBUG} =1; $| =1;
my $PROFILE = {};
our $ORDERBOOKS = Toyhouse::Orderbooks->new();
my $URL = 'wss://ws-feed.pro.coinbase.com';
my $UA = Mojo::UserAgent->new();

sub init($self) {
	die "profile_name required" unless $self->profile_name();
	die "profile_name already exists: ". $self->profile_name() if $PROFILE->{ $self->profile_name() };
	$PROFILE->{ $self->profile_name() } = 1;

	$self->signer( Toyhouse::Signer->new() ) unless $self->signer(); #signer is required even if credentials do not exist
	$self->connect_count(0) unless $self->connect_count();
	$self->json_count(0);

	$ORDERBOOKS->product_ids( $self->product_ids )->build() if $self->profile_name() eq 'ORDER_BOOK_KEEPER';
	$self;
}

sub start($self) {
	$UA->websocket_p($URL)->then(sub ($tx) {
		$self->profile_name( 'I am' ) unless $self->profile_name();

		my $ORDER_BOOK_KEEPER; if ($self->profile_name() eq 'ORDER_BOOK_KEEPER') {
			$self->signer->secret(undef); # 'ORDER_BOOK_KEEPER' must not authenticate so we unset secret
			$ORDER_BOOK_KEEPER = 1;
		}

		my $promise = Mojo::Promise->new();
		$self->log( "connecting..." );

		$tx->on(json => sub ($tx, $order) { $order = Toyhouse::Model::Order->new( %$order )->build();
			return unless $order->product_id();

			$self->connect_count(0); $self->json_count($self->json_count() +1);

			if ( $order->user_id() ) {
				if ( $order->type() ne 'received' ) {
					if ( $order->type() eq 'match' ) {
						$self->log( $order->to_json() );
						$self->dbh->record( $order->to_json() ) if $self->dbh();
					}
				}
 			}
 			elsif ($ORDER_BOOK_KEEPER) {
 				if ($order->type() eq 'match') {

 					if ($self->dbh) {
						#only record minimal data;
						# we set the product_id so it will be appended to the table_name we are writing to. 						
						$self->dbh->product_id( $order->product_id() );
	 					# write the data to the $table_name_$product_id
	 					$self->log( 'recorded', $order->product_id(), $order->type(), '#'.
	 						$self->dbh->record( Toyhouse::Model::Order->new(
								price		=> $order->price(),
								product_id	=> $order->product_id(),
								side		=> $order->side(),
								size		=> $order->size(),
								time		=> $order->time())->build->to_json()));
	 				}
 				}
 			}
		});

		$tx->on(finish => sub { $self->log( "disconnected" ); $self->start() }); #sub promise { this is a promise  that never ends, yes it goes on and on my friend.. some people started running it not knowing what it was, and they continue running it forever just because... promise()

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

sub log ($self, @message) { say join(" ", $self->profile_name, @message) }