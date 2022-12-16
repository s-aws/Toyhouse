package Toyhouse::Core::_::websocket;
use warnings;
use strict;

use EV;
use AnyEvent;
use AnyEvent::WebSocket::Client;
use JSON qw/decode_json/;
use Data::Dumper;

my $scope = 'coinbase';
my $complete_message = 'done';
my $connecting_message = 'connecting..';
my $disconnected_message = ' disconnected...';
my $default_subscription_type = 'subscribe';
my $default_subscription_channel = ['full'];
my $ua_header = "User-Agent";
my $agent = "Toyhouse/1.0 (Perl)";
my $subscription_sent_message = 'signed subscription sent';
my $end_statement = "\n";
my $server = "wss://ws-feed.pro.coinbase.com";
my $match_type = 'match';
my $my_type = 'user_id';
my $message_filter = "$match_type|$my_type";
my $DEFAULT_METHOD 	= "GET";
my $ws_flag 		= "ws";
my $signer_env_flag = "env";
my $fatal_text = 'fatal';
my $error_pipe_closed = 'error pipe closed! exiting thread!!!';
my $end_pipe_session = chr(1);
my $sep = ' ';

*ws_auth = sub {

	#Get a signature
	return Toyhouse::base::coinbase::auth::signer->set($signer_env_flag => $ws_flag)->new($DEFAULT_METHOD)->ws_json(shift)};

*new = sub {
	my $iPipe = 0;
	my $self = bless { }, shift;
	my $order_ids = shift; #this is passed from coinbase.pm
	my $OUT = shift;

	# setup websocket client with user agent
	my $client = AnyEvent::WebSocket::Client->new( http_headers => [$ua_header, $agent] );

	#advertising our status and also logging
	print STDERR $connecting_message;

	# connecting to websocket
	$client->connect(URI->new($server))->cb(sub {

			#$self->{helper}->{console}->{start}->();
			our $connection = eval {shift->recv};
			do {print STDERR $@; EV::break; sleep 1; return} if $@;
			print STDERR $complete_message . $end_statement;

			# timer to keep the websocket from disconnecting
			$self->{timer_w} = AnyEvent->timer(
				after => 0,
				interval => 3, #subscribe every interval seconds
				cb => sub {

				# setup subscription hash which includes product_id arrah hash
					my $subscription = {type		=> $default_subscription_type,
										product_ids	=> $order_ids,
										channels	=> $default_subscription_channel};

				# sending the subscription over the websocket
				$connection->send( ws_auth($subscription) );			#sending the signed subscription request
			});

			# advertising our success? we have no knowledge of success at this point
			print STDERR $subscription_sent_message . $end_statement;


			# for each websocket message
			$connection->on(each_message => sub {
				print $OUT $_[1]->body, $end_statement;

			});

			$connection->on(finish => sub { #clean up before exiting

				#we disconnected for some reason, adversting our failure and logging
				print STDERR join($sep,__PACKAGE__, $disconnected_message . $end_statement);

				#unsetting subscription timer
				undef $self->{timer_w};

#				print $OUT $end_pipe_session . $end_statement;
#				close $write;
				EV::break;					
			});
	});
	EV::run; #so we don't exit immediately
#		exit;
#	}
#	wait;

};

1;