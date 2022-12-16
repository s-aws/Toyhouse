package logger {
	BEGIN {require Toyhouse::Logging}
	*new = sub { new Toyhouse::Logging () };
}

package secure {
	BEGIN {	

		require Math::Random::Secure;
		*rand 				= *Math::Random::Secure::rand;
		my $max32bit 		= 2^32;
		sub nonce {
			rand($max32bit)
		}

		require Digest::SHA;	import Digest::SHA;
		*hmac_sha256 		= *Digest::SHA::hmac_sha256;
		*hmac_sha256_hex 	= *Digest::SHA::hmac_sha256_hex;
		sub hmac_sha256_hex_w_nonce {
			hmac_sha256_hex(@_, nonce())
		}

		require MIME::Base64; 	import MIME::Base64 	();
		*encode_base64 		= *MIME::Base64::encode_base64;
		*decode_base64 		= *MIME::Base64::decode_base64;

	}

	1;
}

package json_tools {
	BEGIN {

		require JSON; import JSON ();
		*encode_json = *JSON::encode_json;
		*decode_json = *JSON::decode_json;
	}

	1;
}

package fork_manager {
	use warnings;
	use strict;

	BEGIN {require Toyhouse::Core}

	sub new {bless {}, shift}
	sub create {
		my ($self, $cb) = (shift, shift);
		if (my $pid = fork()) { #main
			$self->{pid}->{$pid} = 1;
			return $pid
		}
		else { #fork
			$cb->(@_);
			exit;
		}
	}	

	1;
}

package pipe_manager {
	use warnings;
	use strict;

	BEGIN {require Toyhouse::Core}

	sub new {bless {$Toyhouse::Core::PIPE_MANAGER_COUNTER_NAME => $Toyhouse::Core::FIRST_ITEM_IN_LIST}, shift}
	sub create { 	# Pipe pair created and stored in the following hash location
					# self->{$pipe_default_state}->{$N}->{$type_name}
		my ($self, $R, $W) = (shift, undef, undef);
		if (pipe($R, $W)) {
			$self->{$Toyhouse::Core::PIPE_MANAGER_COUNTER_NAME} += $Toyhouse::Core::PIPE_MANAGER_PIPE_INCREASE_AMOUNT;
			my $N = Toyhouse::Core->nonce;
			*$R{$Toyhouse::Core::IO_CONSTANT}->autoflush;
			*$W{$Toyhouse::Core::IO_CONSTANT}->autoflush;
			$self->{$Toyhouse::Core::PIPE_MANAGER_DEFAULT_CREATE_STATE}->{$N} = { $Toyhouse::Core::PIPE_MANAGER_READER_NAME => *$R{$Toyhouse::Core::IO_CONSTANT}, $Toyhouse::Core::PIPE_MANAGER_WRITER_NAME => *$W{$Toyhouse::Core::IO_CONSTANT} };
			return $N}
		else {undef}}

	sub get_read {
		return undef unless $Toyhouse::Core::has_number_of_parameters->(2, @_) && defined($_[0]->{$Toyhouse::Core::PIPE_MANAGER_DEFAULT_CREATE_STATE}) && defined($_[0]->{$Toyhouse::Core::PIPE_MANAGER_DEFAULT_CREATE_STATE}->{$_[1]});
		$_[0]->{$Toyhouse::Core::PIPE_MANAGER_DEFAULT_CREATE_STATE}->{$_[1]}->{$Toyhouse::Core::PIPE_MANAGER_READER_NAME}}

	sub get_write {
		return undef unless $Toyhouse::Core::has_number_of_parameters->(2, @_) && defined($_[0]->{$Toyhouse::Core::PIPE_MANAGER_DEFAULT_CREATE_STATE}) && defined($_[0]->{$Toyhouse::Core::PIPE_MANAGER_DEFAULT_CREATE_STATE}->{$_[1]});
		$_[0]->{$Toyhouse::Core::PIPE_MANAGER_DEFAULT_CREATE_STATE}->{$_[1]}->{$Toyhouse::Core::PIPE_MANAGER_WRITER_NAME}}

	1;
}

package https_config {
	BEGIN {
		our $default_options = {
			Host 			=> ['localhost:443'],
			KeepAlive 		=> [60, 1 .. 300],
			SendTE 			=> ['gzip'],
			HTTPVersion 	=> [1.1, 1.0],
			PeerHTTPVersion => [1.1, 1.0],
			MaxLineLength 	=> [0, 1 .. 65535],
			MaxHeaderLines 	=> [0, 1 .. 128]
		}
	}
}

package https_client {
	use warnings;
	use strict;

	BEGIN {require Net::HTTPS}

	my $default_options = $https_config::default_options;

	my $options = sub {
		my $options = {};
		foreach my $key (keys %$default_options) {
			$options->{$key} = $default_options->{$key}[0]
		}
		$options->{Host} = shift . ':443' if $_[0];
		$options;
	};

	sub new_connection {
		my $opts = (scalar @_ == 2) ? $options->(pop(@_)) : undef;
		Net::HTTPS->new( %$opts);
	}

	1;
}


package Toyhouse::Core;
use warnings;
use strict;
use FindBin;
use Readonly;
$SIG{CHLD} = "IGNORE"; #we don't like no zombies
BEGIN {

	*decode_base64 		= *secure::decode_base64;	
	*decode_json 		= *json_tools::decode_json;
	*encode_base64 		= *secure::encode_base64;
	*encode_json 		= *json_tools::encode_json;

	*hmac_sha256 		= *secure::hmac_sha256;
	*hmac_sha256_hex 	= *secure::hmac_sha256_hex;

	*hmac_sha256_hex_w_nonce = sub {secure::hmac_sha256_hex_w_nonce(@_, nonce())};

	*logger 			= *logger; # using Log4perl
	*nonce 				= *secure::nonce;
	*new_https_connection = *https_client::new_connection;
	*new_pipe 			= sub {pipe_manager->new};
	*new_fork			= sub {fork_manager->new};

	# websocket client should not have lived here
	require Toyhouse::Core::_::websocket_client;

	*DECODE_JSON = *decode_json;
	*ENCODE_JSON = *encode_json;
	*HMAC_SHA256_HEX_W_NONCE = *hmac_sha256_hex_w_nonce;
}

our Readonly $_SDK_NAME = 'Toyhouse';
our Readonly $_SDK_VERSION = 0.1;
our Readonly $_SDK_LANGUAGE = 'Perl/5';

our ($AUTHENTICATION_TYPE);
our Readonly $IO_CONSTANT = 'IO';

our Readonly $CLIENT_NEW_REQUIRED_PARAMETER_COUNT = 2;
our Readonly $EXACT = 'only';

our Readonly $LIBRARY_STORE_COMMAND = 'store';
our Readonly $LIBRARY_GET_COMMAND = 'retrieve';

our Readonly $NAME_SEPARATOR = '_';
our Readonly $COMMAND_SEPARATOR = $NAME_SEPARATOR;
our Readonly $CMD_BUILDER = sub {join ($COMMAND_SEPARATOR, @_)};
our Readonly $API_CMD_BUILDER = sub {my $work = $_[0]; $work =~ s/ /_/g; lc($work)};
our Readonly $NONCE = sub {secure::nonce()};

our Readonly $API_CONFIG_USER_AGENT = $CMD_BUILDER->($_SDK_NAME, $_SDK_VERSION, $_SDK_LANGUAGE);

our Readonly $PRO_COINBASE_API_AUTH_KW = 'pro_api';
our Readonly $PRO_COINBASE_API_AUTH_KEYS = ['key', 'secret', 'passphrase'];

our Readonly $PIPE_MANAGER_COUNTER_NAME = 'counter';
our Readonly $PIPE_MANAGER_DEFAULT_CREATE_STATE = 'open';
our Readonly $PIPE_MANAGER_NAME = 'pipe';
our Readonly $PIPE_MANAGER_PIPE_INCREASE_AMOUNT = 2;
our Readonly $PIPE_MANAGER_READER_NAME = 'reader';
our Readonly $PIPE_MANAGER_WRITER_NAME = 'writer';

our Readonly $FORK_MANAGER_COUNTER_NAME = 'counter';
our Readonly $FORK_MANAGER_DEFAULT_CREATE_STATE = 'open';
our Readonly $FORK_MANAGER_NAME = 'fork';
our Readonly $FORK_MANAGER_FORK_INCREASE_AMOUNT = 1;

our Readonly $SESSION_CMD_PREFIX = 'get';
our Readonly $SESSION_CRED_TYPE = 'credential_type';
our Readonly $SESSION_KEY = 'session_key';
our Readonly $SESSION_NAME = 'name';
our Readonly $SESSION_GET_CMD = sub{$CMD_BUILDER->($SESSION_CMD_PREFIX, @_)};

our Readonly $TRUE_STRING = 'true';
our Readonly $FALSE_STRING = 'false';
our Readonly $TRUE = 1;
our Readonly $FALSE = 0;

our Readonly $CODE_TYPE = uc 'code';
our Readonly $DIRECTORY_PATH_DELIMITER = '/';
our Readonly $DICTIONARY_TYPE = uc 'hash';
our Readonly $STRING_TYPE = uc 'scalar';
our Readonly $LIST_TYPE = uc 'array';
our Readonly $LAST_ITEM_IN_LIST = -1;
our Readonly $STATUS = [1, undef]; # shell commands return -1 if failed
our Readonly $FIRST_ITEM = 0;
our Readonly $FIRST_ITEM_IN_LIST = $FIRST_ITEM;

my Readonly $READ_ALL_FILE = sub {return undef unless $_[0] && defined(is_open_fh($_[0])); my $fh = $_[0]; my $file; while (<$fh>) {$file .= $_}	$file};
*OPEN_FOR_READING = sub {return undef unless $_[0]; my $FH; open($FH, '<', shift); $FH};
*OPEN_FOR_WRITING = sub {return undef unless $_[0]; my $FH; open($FH, '>', shift); $FH};
my Readonly $CLOSE_FILE = sub {return undef unless close $_[0]};
my Readonly $REMOVE_FILE_EXTENSION = sub {return undef unless $_[0]; (split(/\./, $_[0]))[0]};
my Readonly $GET_FILE_NAME_FROM_PATH = sub {return undef unless $_[0]; $REMOVE_FILE_EXTENSION->((split(/$DIRECTORY_PATH_DELIMITER/, $_[0]))[$LAST_ITEM_IN_LIST])};

my Readonly $_LOAD_JSON_LIST_CACHE = {};

our Readonly $has_number_of_parameters = sub {return undef unless ((scalar(@_) -1) == shift); $TRUE};
our Readonly $is_hash = sub {return undef unless ref(shift) eq $DICTIONARY_TYPE; $TRUE};
our Readonly $is_num = sub {return undef unless shift =~ m/^[[:digit:]]+$/; $TRUE};
our Readonly $is_json = sub {return undef unless substr($_[0],0,1) eq '{'; decode_json(shift)};
*is_open_fh = sub {return undef unless @$STATUS[eval{tell(shift)}]; $TRUE};

our $CAMEL = sub {uc(substr($_[0],$FIRST_ITEM,$FIRST_ITEM+1)) . lc(substr($_[0],$FIRST_ITEM+1))}; #Make first character uc and lower the rest
our $EMPTY_NUMBER = $FIRST_ITEM_IN_LIST;
our $EMTPY_LIST = [];
our $EMPTY_HASH = {};
our $EMTPY_STRING = '';

our $CHOMP_ARRAY = sub {return undef unless defined($_[0]); foreach (@{$_[0]}) {chomp}; 1};

our Readonly $NEW_HTTPS_CONNECTION = sub {new_https_connection(@_)};
$AUTHENTICATION_TYPE = {WEBSOCKET => 'websocket', RESTAPI => 'restapi'};

my Readonly $foreach_ = sub {my ($ref, $cb, $phash) = (shift, {@_}->{cb}, {@_}->{phash}); 
	my $check; $check = sub {my $h = shift;
		# handle scalar (use callback)
		if (!ref($h)) {return $cb->($h, $phash)} 
		# handle array
		elsif (ref($h) eq $LIST_TYPE) {return undef unless (scalar(@$h) >= $TRUE); my $array_counter = 0; my $splice_list = [];	foreach (@$h) {my $r = $check->($_); unless ($r) {push @$splice_list, $array_counter} elsif ((ref($r) eq $DICTIONARY_TYPE) && (%$r)) {} else {$_ = $r} $array_counter++} if (scalar(@$splice_list) == scalar(@$h)) {@$h = ()} else {foreach (@$splice_list) {splice(@$h, $_, $TRUE)}}} 
		# handle dictionary: currently doesn't handle multiple keys (nested keys not supported for coinbase right now I think)
		elsif (ref($h) eq $DICTIONARY_TYPE) {my ($r, $k) = (undef, keys(%$h)); return undef unless (scalar(keys(%$h)) >= $TRUE); if ($k) {my $v = $h->{$k}; $r = $check->($v); defined($r) ? $h->{$k} = $r : delete($h->{$k})} return (scalar(keys(%$h)) >= $TRUE) ? $h : undef}
	}; 

	#let's begin
	$check->($ref)};

# parse format... 0 = scalar to process, 1 = hash to pull values from. scalar should relate to the key in the parameter hash.
my Readonly $parse = sub {my ($base, $parameter_hash) = (@_); my $key = ($base =~ m/^\$(.*)/) ? $1 : undef; if (defined($key)) {if (defined($parameter_hash->{$key})) {$parameter_hash->{$key}} else {undef}} else {$base}}; 

my Readonly $check_if_undefined = sub {if (ref($_[0]) eq $DICTIONARY_TYPE) {unless (%{$_[0]}) {return undef}} elsif (ref($_[0]) eq $LIST_TYPE) {unless (defined(@{$_[0]}[0])) {return undef}} else {unless (defined($_[0])) {return undef}} return 1}; #not helpful
my Readonly $remove_undefined = sub {splice(@{$_[0]}, $_[1], 1)}; # not helpful

our Readonly $API_SUBTITUTE_VAR_PLACEHOLDERS = sub {#0 = arrayref, 1 = hashref, 2 = coderef
	return undef unless ref($_[0]) eq $LIST_TYPE; my ($array_hash, $parameter_hash, $cb) = (shift, {@_}, undef); 
	if (ref($_[0]) && (ref($_[0]) eq $CODE_TYPE)) {$cb = shift} else {$cb = $parse}
	my $opts = [cb => $cb, phash => $parameter_hash]; my $array_counter = $FIRST_ITEM;
	$foreach_->($array_hash, @$opts);
#	foreach (@$array_hash) {if (ref($_)) {$if_array_or_hash->($_, @$opts)} else {$_ = $if_array_or_hash->($_, @$opts)}}
};


our $API = sub {
	my ($command,$directory) = (@_);
	my $dir_list_hash = [`ls $directory`];
	return undef unless $CHOMP_ARRAY->($dir_list_hash);	
	return $dir_list_hash || undef;
	#return ['accounts', 'currencies', 'deposits', 'fills', 'orders', 'products', 'time'] if (lc($command) eq 'types')
};

# File load location generator thingy
my Readonly $GET_JSON_FILE_LIST = sub {
#	my $LIST_LOCATIONS = sub {$LOCATIONS->{$_[0]}->($_[0])};
	my $BUILD_LOCATION_OF_JSON = sub {pop(@_) . '/' . $_[0]};
		#$LIST_LOCATIONS->(lc($_[0])) || undef};
	my $location = $BUILD_LOCATION_OF_JSON->(@_);
	my $location_ref = defined($location) ? [`ls $location`] : undef;
#	return undef unless $CHOMP_ARRAY->($location_ref);
#	print STDERR Dumper $location;
	foreach (@{$location_ref}) {
		chomp($_);
		$_ = $location . '/' . $_
	}
#	print STDERR Dumper $location_ref;
	$location_ref
};

*LOAD_JSON_LIST = sub {
	my $cache_key = "@_"; if ($_LOAD_JSON_LIST_CACHE->{$cache_key}) {return DECODE_JSON($_LOAD_JSON_LIST_CACHE->{$cache_key})}
	my ($results_hash);
	my $json_directory = pop(@_);
	foreach my $api (@_) {
		my $file_list = $GET_JSON_FILE_LIST->($api, $json_directory);
		foreach (@{$file_list}) {
			my ($file_name, $data);
			return undef unless ($file_name = $GET_FILE_NAME_FROM_PATH->($_)) && eval{my $fh = OPEN_FOR_READING($_); $data = $READ_ALL_FILE->($fh); $CLOSE_FILE->($fh)};
			eval{$results_hash->{$file_name} = DECODE_JSON($data)} ? next : last;
		}
	}
	$_LOAD_JSON_LIST_CACHE->{$cache_key} = ENCODE_JSON($results_hash);

	$results_hash
};



our Readonly $FORK = fork_manager->new();
our Readonly $PIPE = pipe_manager->new();





1;