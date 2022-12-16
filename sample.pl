use warnings; 
use strict; 

BEGIN {push @INC, '.'}
use EV;
use lib;

# use Toyhouse::API; #updates the Generated packages
use Toyhouse::Generated::coinbase; 
use Toyhouse::Websocket_message_handler;
use Data::Dumper;

my $secret 		=	$ENV{CB_SECRET}; 
my $passphrase 	=	$ENV{CB_PASSPHRASE}; 
my $key 		=	$ENV{CB_KEY};
my $auth = {secret => $secret, passphrase => $passphrase, key => $key};

# new client type (pro_api/api)
my $coinbase = Toyhouse::Generated::coinbase->new(pro_api => $auth);

#my $orders = $coinbase->accounts->set_status('open')->query->list_orders();
#my $products = $coinbase->products->get_products();

$coinbase
	->ws
		->set_type('subscribe')->body
		->set_product_ids([ 'BTC-USD' ])->body
		->set_channels([ 
			#{name => 'user'}, 
			'full',])->body;

#Toyhouse::Client->set_auth_array([$coinbase, $coinbase2, $coinbase3, $coinbase4]);
my $read_pipe = $coinbase->create_websocket;

my $websocket_handler = Toyhouse::Websocket_message_handler->new(cc => [$coinbase]);

my $test = Toyhouse::Websocket_message_handler::start_reading_pipe($websocket_handler => read_pipe => $read_pipe);

EV::run;
wait();

1;