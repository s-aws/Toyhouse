package service_manager {
	use warnings;
	use strict;

	BEGIN {require Toyhouse::Core}
	use AnyEvent;

	CORE::state $SERVICES = {};
	CORE::state $LOGGER = [];

	sub parse_command {
		my ($input, $caller) = @_;
		if (defined(my $job = <$input>)) {
			$job =  $Toyhouse::Core::is_json->($job);
			# here we parse commands
			if (defined $job->{command}) {

			}
			else {
				return $job
			}
		}
		return undef
	}

	sub websocket_cb_builder {
		sub parse_order {
			my $o = shift;
			if ($o->{type}) {
				# this is a (coinbase) order message
			}
			else {
				print STDERR "FOR SOME REASON...: $_";
				return undef
			}
		}

		my $me = 'websocket';
		my $write_to_pipe_cb = sub { # lives in a thread, so exit() is the best way out. The only thing that lives in this thread at this time.
			my $ws = Toyhouse::Core::_::websocket_client->new(@_);
			$ws->
				connect()->
				subscribe_and_listen();
			_exit();
		};

		our $read_from_pipe_cb = sub {
			my $orders = {};
			my $read_pipe = shift; 
			my $work = [];
			my $io_watcher; $io_watcher = AnyEvent->io (fh => *$read_pipe, poll => 'r', cb => sub {
				push @{$work}, scalar(<$read_pipe>);

				my $idle_watcher; $idle_watcher ||= AnyEvent->idle (cb => sub {
					if (my $msg = shift @{$work}) {
						our $o = parse_command($read_pipe, $me);
					 	parse_order($o);
						print STDERR sprintf("ws:second_pipe:idle_reader: %d\n", $orders->{i}++);
					}
					else {
						undef $idle_watcher;
					}
				});
			});
			EV::run;
		};

		return ($write_to_pipe_cb, $read_from_pipe_cb)
	}

	sub fork_and_track {
		#fork_and_track(name, cb, (parameters, for, cb), pipe)
		my $service_name = shift;
		push @{$SERVICES->{$service_name}->{pid}}, $Toyhouse::Core::FORK->create(@_);
	}

	sub get_last_child_pid {
		my $service_name = pop;
		return pop @{$SERVICES->{$service_name}->{pid}}
	}

	sub begin_service {
		my $self = shift;
		my $service_name = shift;
		$self->{pipe_id} = 		$Toyhouse::Core::PIPE->create();
		$self->{read_pipe} =	$Toyhouse::Core::PIPE->get_read($self->{pipe_id});
		$self->{write_pipe} = 	$Toyhouse::Core::PIPE->get_write($self->{pipe_id});

		if ($service_name eq 'websocket') {
			($self->{write_to_pipe_cb}, $self->{read_from_pipe_cb}) = websocket_cb_builder();
			#fork_and_track($service_name, $read_from_pipe_cb, $read_pipe);
			fork_and_track($service_name, ($self->{write_to_pipe_cb} => @_), $self->{write_pipe});
		}

		push @{$LOGGER}, $self->{read_pipe};
		return $self;

	}

	sub get_readpipe {
		my $self = shift;
		return $self->{read_pipe} if defined $self->{read_pipe};
	}

	sub begin_websocket_service {
		my $self = bless {}, shift;
		my $service_name = 'websocket';
		my ($session, $subscribe) = @_;
		my $service = $self->begin_service($service_name, $session, $subscribe);
		$service;
	}

	1;
}

package Toyhouse::Client;
use warnings;
use strict;

#
##
## my $secret 		=	$ENV{CB_SECRET};
## my $passphrase 	=	$ENV{CB_PASSPHRASE};
## my $key 		=	$ENV{CB_KEY};
## my $auth = {secret => $secret, passphrase => $passphrase, key => $key};
##
## my $client_ws = new Toyhouse::Client pro_api => $auth;
## my $client_restapi = new Toyhouse::Client rest_api => $auth;
##
## $client->{get_credential_type};
## $client->{get_session_key};
#


BEGIN {require Toyhouse::Core}
my $auth_parameter_keys 		= 	$Toyhouse::Core::PRO_COINBASE_API_AUTH_KEYS;
my $get_command 				= 	sub {$Toyhouse::Core::SESSION_GET_CMD->(@_)};
my $has_number_of_parameters 	= 	sub {$Toyhouse::Core::has_number_of_parameters->(@_)};
my $is_hash 					= 	sub {$Toyhouse::Core::is_hash->(@_)};
my $new_required_parameter_count=	$Toyhouse::Core::CLIENT_NEW_REQUIRED_PARAMETER_COUNT;
my $pro_coinbase_api_auth_kw 	=	$Toyhouse::Core::PRO_COINBASE_API_AUTH_KW;
my $session_cred_label 			= 	$Toyhouse::Core::SESSION_CRED_TYPE;
my $session_key_label 			= 	$Toyhouse::Core::SESSION_KEY;

BEGIN {require Toyhouse::Client::request}
my $new_https_client 	= sub {Toyhouse::Client::request->new_https_client()};
my $send_request 		= sub {Toyhouse::Client::request->generate_request(@_)};

my $key 		= @$auth_parameter_keys[0];
my $passphrase 	= @$auth_parameter_keys[2];
my $secret 		= @$auth_parameter_keys[1];

my $has_required_auth_keys	= sub {
	return undef unless 
		(shift eq $pro_coinbase_api_auth_kw) && 
		defined($_[0]->{$secret}) && 
		defined($_[0]->{$passphrase}) && 
		defined($_[0]->{$key})};


BEGIN {require Toyhouse::Client::regex}
my $is_only_hexadecimal		= sub {$Toyhouse::Client::regex::is_only_hexadecimal->(@_)};
my $is_only_alphanumeric	= sub {$Toyhouse::Client::regex::is_only_alphanumeric->(@_)};

BEGIN {require Toyhouse::Session}
sub new_session {
	my $self = shift;  #currently not used
	my $auth_is_proper = sub {
		return undef unless 
			$has_number_of_parameters->(
				$new_required_parameter_count, 
				@_) && 
			$is_hash->($_[1]) && 
			$has_required_auth_keys->(@_) && 
			$is_only_hexadecimal->($_[1]->{$key})};

	return undef unless $auth_is_proper->(@_);
	my $session = new Toyhouse::Session @_;

	return {
			$session_key_label 	=> $session->{$session_key_label},
			$session_cred_label => $session->{$session_cred_label}}
}

#sub set_auth_array {
#	shift;
#	service_manager::set_auth_array(shift);
#}

BEGIN {require Toyhouse::Core::_::websocket_client}
our $new_websocket_session = sub {
	return service_manager->begin_websocket_service(shift, shift);
};

our $send = sub {
	my $r = $send_request->(@_);
	return (
		$r->{status_code}, 
		$r->{message}, 
		$r->{body},)
};
 
1;