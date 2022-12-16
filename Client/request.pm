package Toyhouse::Client::request;
use warnings;
use strict;

use Toyhouse::Auth::signature;
use Toyhouse::Session;
use Toyhouse::Core;
use Net::HTTPS;
use Time::HiRes qw/usleep/;
use JSON;
use Data::Dumper;
use Readonly;

my Readonly $MICROS_IN_A_SECOND = 1000000;
my $MAX_REQUESTS_PER_SECOND = 1;
my $MAX_RPS_IN_MICROSECONDS = $MICROS_IN_A_SECOND / $MAX_REQUESTS_PER_SECOND;

my $MAX_PAGINATION_REQUESTS = 10;
my $VERBOSE_PAGINATION = $Toyhouse::Core::FALSE;

my $session_key_label 	= $Toyhouse::Core::SESSION_KEY;
my $StaticPlaceOrderCommand = 'post';
my $StaticRemoveOrderCommand = 'delete';
my $DEFAULT_METHOD 	= "GET";
my $CT_label 		= "Content-Type";
my $UA_label 		= "User-Agent";
my $conn_host_key 	= "Host";
my $conn_read_size 	= 1024;
my $default_content = '';
my $required_prefix = '/';
my $required_json_prefix = '{';
my $contentType 	= "application/json";
my $ua 				= "Toyhouse/1.0 (Perl)";
#my $host 			= "d3mvlnxge5758t.cloudfront.net";
my $host 			= "api.pro.coinbase.com";
my $port 			= 443;
my $anyevnt_pol_read = 'r';
my $error_fail_open = 'error: open pipes failed!!';
my $error_fatal 	= 'fatal';
my $error_sep 		= ' ';

sub sign {
	my $sign = sub {
		my ($auth_hash, $method, @args) = (@_);
		return Toyhouse::Auth::signature->new($auth_hash, $method, @args);
	};

	my ($self, $session, $method, $path, $body) = (@_); 
	my $auth = Toyhouse::Session->get($session->{$session_key_label});
	$self->{request_to_upstream} = $sign->($auth, $method, $path, $body);
	return $self->{request_to_upstream};
}

my $new_https_connection = sub {$Toyhouse::Core::NEW_HTTPS_CONNECTION->(@_)};
my $hash = sub {$Toyhouse::Core::DICTIONARY_TYPE};

sub new_https_client {
	$new_https_connection->('pro.coinbase.com');
}

my $stringify = sub {

};

sub set_max_rps {
	my ($self, $rps) = @_;
	$MAX_REQUESTS_PER_SECOND = $rps;
	$MAX_RPS_IN_MICROSECONDS = $MICROS_IN_A_SECOND / $MAX_REQUESTS_PER_SECOND;	
	$self
}

sub get_max_rps {
	return $MAX_REQUESTS_PER_SECOND
}

sub set_max_pagination_requests {
	my ($self, $mpr) = @_;
	$MAX_PAGINATION_REQUESTS = $mpr;
	$self
}

sub get_max_pagination_requests {
	return $MAX_PAGINATION_REQUESTS
}

sub enable_verbose_pagination {
	my ($self, $vp) = (shift, $Toyhouse::Core::TRUE);
	$VERBOSE_PAGINATION = $vp;
	$self
}

sub disable_verbose_pagination {
	my ($self, $vp) = (shift, $Toyhouse::Core::FALSE);
	$VERBOSE_PAGINATION = $vp;
	$self
}

sub get_verbose_pagination {
	return $VERBOSE_PAGINATION
}

sub generate_request {
	my ($code, $body, $header);
	my ($self, $session, $method, $path, @opts) 	= (@_); 
	$self = bless {}, $self;
	
	my $request_to_upstream;
	# setup the http request

	$request_to_upstream->{content} 		= defined($opts[0]) 	? $opts[0]	: '';   
	$request_to_upstream->{method} 			= defined($method) 		? $method 	: $DEFAULT_METHOD;  
	$request_to_upstream->{path} 			= defined($path) 		? eval{(substr($path, 0, 1) ne $required_prefix) ? $required_prefix.$path : $path} : $required_prefix;

	# temp, kinda- using this for pagination for now
	my $old_path = $request_to_upstream->{path};

	my $prepare_request = sub { 	

		my $rtu = $self->sign($session, $request_to_upstream->{method}, $request_to_upstream->{path}, $request_to_upstream->{content});

		# required by all requests
		$request_to_upstream->{headers} = $rtu->{headers};
		$request_to_upstream->{headers}->{$UA_label} 	= $ua;
		$request_to_upstream->{headers}->{$CT_label} 	= $contentType;

		# updating content (json form);
		$request_to_upstream->{content} = $rtu->{body};

    	# creating client
		$request_to_upstream->{Client} = Net::HTTPS->new($conn_host_key => $host) or die $@;
	};

	use Data::Dumper;

	my $get_response = sub {	#Send the request and read the response
		$request_to_upstream->{Client}->write_request(
			$request_to_upstream->{method} =>
				$request_to_upstream->{path},
				%{$request_to_upstream->{headers}},
				eval{$request_to_upstream->{content} || $default_content});

		#accepting request line (http code and message) and header(hash)
		my ($c, $b, %h) = $request_to_upstream->{Client}->read_response_headers;

		# getting body
		while (1) {
			my $buf;
			my $n = $request_to_upstream->{Client}->read_entity_body($buf, $conn_read_size);
			die join($error_sep, $!, $error_fatal) unless defined $n;
			last unless $n;
			$body .= $buf;
		}

		# make all the headers lowercase
		foreach my $header (keys(%h)) {
			$h{lc($header)} = delete $h{$header} unless lc($header) eq $header;
		}

		return ($c, \%h);
	};

	# Do the request/response look and do pagination
	my ($i, $delay, $page_counter, $max_pages) = (0, $MAX_RPS_IN_MICROSECONDS, 0, $MAX_PAGINATION_REQUESTS);
	usleep ($delay * 2);

	while (1) {
		$prepare_request->();
		($code, $header) = $get_response->();
#		print STDERR "code => $code\n";

		if ($code == 429) {
			$delay *= 2 * $i++;
		}
		else {
			$page_counter++;
			last unless $header->{'cb-after'} && ($page_counter <= $max_pages); # max_pages is the number of paginated pages, not total pages
		}

		if (defined($header->{'cb-after'})) { # pagination # needs to be changed to be variable

			print STDERR " $page_counter" if get_verbose_pagination() == $Toyhouse::Core::TRUE; # pagination verbosity

			$request_to_upstream->{path} = ($old_path !~ m{\?}) ? "$old_path?after=$header->{'cb-after'}" : "$old_path&after=$header->{'cb-after'}";
		}

		usleep $delay;		
	}

	# I'm concatenating json (arrays) and so the following cleans them up to make them valid-ish
	if ((defined($body)) && ($body ne '')) { #in case body is undef? need to find out why this happens
		$body =~ s{\[\]}{}g;
		$body =~ s{\]\[}{,}g;
	}

	$body = eval{return decode_json($body) unless !defined($body) or ($body eq '')};

	#returning the goodies
	return {
		status_code => $code,
		message => $header->{message},
		%{$header},
		body => $body
	}
}

1;