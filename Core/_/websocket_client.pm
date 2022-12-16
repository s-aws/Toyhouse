package websocket_config {
	BEGIN {
		our $default_options = {
			ua_header => 'User-Agent',
			agent => 'Toyhouse/1.0 (Perl)',
			subscription => {
				type => 'subscribe',
				channel => ['full']
			},
			server => 'wss://ws-feed.pro.coinbase.com',
			method => 'GET',
			body => '',
			flags => {
				signer_env => 'env',
				ws => 'ws'
			}
		}
	}
}

package Toyhouse::Core::_::websocket_client;
use warnings;
use strict;
use EV;
$|=1;

use Data::Dumper;


BEGIN {require EV; import EV (); require AnyEvent; import AnyEvent (); require AnyEvent::WebSocket::Client; import AnyEvent::WebSocket::Client ()}#require Toyhouse::Session}

my $default_options = $websocket_config::default_options;

sub ws_auth {
	my $auth = shift;
	my $subscription = shift; 
#		print STDERR Dumper $default_options;
	
	my $sig = Toyhouse::Auth::signature->set(
		$default_options->{flags}->{signer_env} => $default_options->{flags}->{ws}
	)->new(
	#method and path are required for a signature https://docs.pro.coinbase.com/?r=1#subscribe
		$auth,
		$default_options->{method},
		$default_options->{body});

	return Toyhouse::Core::encode_json({ #combining into a single hash
		%{$sig->{headers}}, 
		%{$subscription}
	})
}

sub new {
	use Data::Dumper;
	my $self = shift;
	my ($session, $body, $OUT) = @_;

	my $client = AnyEvent::WebSocket::Client->new(
		http_headers => [
			$default_options->{ua_header}, 
			$default_options->{agent}]
	);

#		my $auth = Toyhouse::Session->get($session->{session_key});

	return bless {
		body => $body,
		OUT => $OUT,
		session_key => $session->{session_key},
		client => $client,
		auth => sub {Toyhouse::Session::get->(@_)},
		generate_subscription_json => sub {
			my ($session_key, $body, $json) = (@_, undef);
			$json = ws_auth($session_key, $body);
			return $json;
		}
	}, $self;
}

sub connect { # testing how code looks dereferences on different lines
	my $config = shift;

	my $client = 
		$config->
			{client};

	my $OUT = (
		$config->
		{OUT} && 
			Toyhouse::Core::is_open_fh->(
				$config->
				{OUT})) ? 
					$config->
					{OUT} : 
						undef;

	*STDOUT = *$OUT if defined($OUT);

	$config->{connection} = $client->
	connect(
		URI->
		new(
			$default_options->
			{server}
		)
	);
	return $config
}

sub subscribe_and_listen {
	my $config = shift;
	my $connection = $config->{connection};
	my $IN = $config->{IN}; 
	$|=1;

	$connection->
	cb(
		sub {
			our $connection = eval {
				shift->
				recv
			};

			do {print $@; EV::break; sleep 1; return} if $@;

			print qq/{"test_output": "connected..."}\n/;

			my $subscribe_json = (
				$config->
				{generate_subscription_json}->(
					$config->
					{auth}->(
						pro_api => 
							$config->
							{session_key}
					), 
					$config->
					{body}
				)
			);

			print qq/{"test_output": "sending subscription: ..."}\n/;

			$connection->
			send(
				$subscribe_json 
			);

			print qq/{"test_output": "subscribed..."}\n/;

			sub working {
				return "\012", 
					substr(
						rand(
							1
						),
						1
					)
			}

			$connection->
				on(each_message => 
					sub {
						print $_[1]->
							body . "\n";
			});

			$connection->
			on(finish => 
				sub {
					print "\004\n"; # end session character... nothing else to process on this side, should exit as quickly as possible
					# let's try leaving this for now
					#EV::break;
				}
			);
		}
	); EV::run;
}

1;
