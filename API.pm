package file_manager {
	use warnings;
	use strict;


	BEGIN {
		require Toyhouse::Core; 
		*logger = *Toyhouse::Core::logger;
		*encode_json = *Toyhouse::Core::encode_json;
		*decode_json = *Toyhouse::Core::decode_json;
	}

	my Readonly $logger = new logger;
	my Readonly $status = [1, undef]; # shell commands return -1 if failed
	my Readonly $package_base_name = 'Toyhouse';
	my Readonly $is_open_fh = *Toyhouse::Core::is_open_fh;

	my $simple_error = sub {
		my $expected_arguments_count = shift;
		my $message = {fatal_count => shift};
		sprintf($message->{fatal_count}, $expected_arguments_count);
	};

	*get_current_bin = sub {return $FindBin::Bin};

	*chomp_array = sub {
		# requires @location
		unless (ref($_[0]) && (ref($_[0]) eq 'ARRAY')) {
			fatal $logger $simple_error->(1, 'chomp_array did not receive %i arguments');
			return undef;
		}

		my $location_ref = shift;
		map{chomp} @{$location_ref};
	};

	*api = sub {
		# requires $command
		# requires $directory
		my ($command,$directory) = (@_);
		
		if (scalar(@_) ne 2) {
			fatal $logger $simple_error->(2, 'api did not receive %i arguments');
			return undef
		}

		unless (my $dir_list_hash = [`ls $directory`]) {
			fatal $logger $simple_error->('not sure where', 'an error occured: %s');
			return undef
		}
		else {
			chomp_array($dir_list_hash);
			return $dir_list_hash
		}

	};


	my Readonly $read_all_file = sub {
		# requires *filehandle
		return undef unless $_[0] && defined($is_open_fh->($_[0])); 
		my $fh = $_[0]; my $file;	
		while (<$fh>) {$file .= $_}	$file};

	*open_for_reading = sub {
		return undef unless $_[0]; 
		my $FH; open($FH, '<', shift); 
		$FH};

	*open_for_writing = sub {
		return undef unless $_[0]; 
		my $FH; open($FH, '>', shift); 
		$FH};

	my Readonly $close_file = sub {
		return undef unless close $_[0]};

	my Readonly $remove_file_extension_from_filename = sub {
		return undef unless $_[0]; 
		(split(/\./, $_[0]))[0]};

	my Readonly $get_file_name_from_path = sub {
		return undef unless $_[0]; 
		$remove_file_extension_from_filename->((split(/\//, $_[0]))[-1])};	

	# File load location generator thingy
	my Readonly $get_json_file_list = sub {
		my $directory = pop(@_) . '/' . $_[0];
		my $filenames = defined($directory) ? [`ls $directory`] : undef;
		chomp_array($filenames);
		my $file_directory_list = [map{[$_ => $directory . '/' . $_]} @{$filenames}]};


	*load_json_from_list = sub {
		BEGIN {require v5.10}
		CORE::state $_json_list_cache;

		$logger->fatal('load_json_list');
		my $cache_key = "@_"; if ($_json_list_cache->{$cache_key}) {return decode_json($_json_list_cache->{$cache_key})}
		my ($results_hash);
		my $json_directory = pop(@_);
		$logger->fatal("arguments: @_");		
		$logger->fatal(sprintf('json_directory: %s', $json_directory));		
		foreach my $api_name (@_) {
			my $json_file_info_list = $get_json_file_list->($api_name, $json_directory);

			foreach (@{$json_file_info_list}) {
				my ($filename, $fullpath) = @{$_};
				my $parameter_name = $remove_file_extension_from_filename->($filename);
				my ($data);

				$logger->fatal($fullpath);
				return undef unless eval{
					my $fh = open_for_reading($fullpath); 
					$data = $read_all_file->($fh); 
					$close_file->($fh);
				};

				eval{$results_hash->{$parameter_name} = decode_json($data)} ? 
					next : 
					last;
			}
		}
		$_json_list_cache->{$cache_key} = encode_json($results_hash);

		$results_hash
	}
}


package Toyhouse::API;
use warnings;
use strict;
use lib;
use Data::Dumper;
use Readonly;

BEGIN {require FindBin; require Toyhouse::Core; *logger = *Toyhouse::Core::logger}

my Readonly $hash = 		$Toyhouse::Core::DICTIONARY_TYPE; 
my Readonly $array = 		$Toyhouse::Core::LIST_TYPE; 
my Readonly $string =	 	$Toyhouse::Core::STRING_TYPE;

my Readonly $logger = new logger;

sub generate_config {
	my $lib_dir = $FindBin::Bin;

	my $dir_sep = '/';
	my $package_sep = '::';
	my $space = ' ';
	my $json_suffix = '.json';
	my $perl_package_suffix = '.pm';

	my $base_dir = 'Toyhouse';
	my $api_json_dir = 'API'; #temp
	my $generated_dir = 'Generated';
	my $filename = 'coinbase';
	my Readonly $read_only = 'Readonly';
	my Readonly $base = 'api';
	my Readonly $do_something_verb = $base . '_action';

	my $full_json_path = join($dir_sep, $lib_dir, $base_dir, $api_json_dir);
	my $full_generated_dir_path = join($dir_sep, $lib_dir, $base_dir, $generated_dir);
	my $full_generated_output_file_path = join($dir_sep, $full_generated_dir_path, $filename . $perl_package_suffix);

	my Readonly $iam_from_caller = ['my $iam = (split(/::/, (caller(1))[3]))[-1]; ' ."\n\t", 
									'$iam =~ s/set_?(.*)/$1/; ' ."\n\t". '$iam;'];

	my Readonly $dereference = 	sub {'->{'.$_[0].'}'};
	my Readonly $parameter = 	sub {'$_['. shift .']'};
	my Readonly $define_sub = 	sub {'sub %s {' . "\n\t" . shift . "\n" . '}' . "\n"};
	my Readonly $define_anon_sub = sub {'my '. $read_only .' %s = sub {' . "\n\t" . shift . "\n" . '};' . "\n"};
	my Readonly $return_undef_unless = sub {'return undef unless ('. shift .'); ' . "\n"};

	my Readonly $use_package = sub {my $r; foreach (@_) {$r .= "use $_;\n"} $r};
	my Readonly $warnings_and_strict = $use_package->(	warnings => 
														strict => 
														$read_only => 
														'Data::Dumper' => 
														'Toyhouse::Client');

	my Readonly $ofw = 			*file_manager::open_for_writing;
	my Readonly $api_names = 	*file_manager::api->(types => $full_json_path); 
	my Readonly $api_config = 	*file_manager::load_json_from_list; 
	my Readonly $config = $api_config->(@$api_names => $full_json_path);
	my Readonly $TEST = $ofw->($full_generated_output_file_path);

	my $package_code = {};
	my Readonly $make_sub_like = sub {
		# make $scalar ok to use as a function/subroutine name
		return undef unless $_[0];

		my $original = $_[0];
		# step 1, remove any non word/number char from the beginning
		$_[0] =~ s/^((\W|[0-9])+)//;

		#step 2, replace - with _
		$_[0] =~ s/\-/_/g;

		#step 3, replace the rest of the non  wordchars
		$_[0] =~ s/(\W+)//g;

		#aaand lowercase we're done.
		my $final = lc $_[0];
		$logger->fatal(sprintf('make_sub_like(%s): %s', $original, $final)) unless ($original eq $final);
		return $final
	};

	# Resulting config hash
	{	code => {
			warnings_and_strict => $warnings_and_strict,
			iam_from_caller => $iam_from_caller,
			dereference => $dereference,
			parameter => $parameter,
			define_sub => $define_sub,
			define_anon_sub => $define_anon_sub,
			return_undef_unless => $return_undef_unless,
			use_package => $use_package},
		base => $base,
		get_api_types => $api_names,
		make_sub_like => $make_sub_like,
		readonly => $read_only,
		config => $config,
		output_file => $TEST,
		package_sep => $package_sep,
		package_path => [$generated_dir, $filename]
	}

}

sub generate_code {
	my $config_hash = shift;
	my ($package_code, $method_hash, $path_hash, $parameter_hash) = ({},{},{},{});	
	my $base = $config_hash->{base};
	my $make_sub_like = $config_hash->{make_sub_like};
	my $define_sub = $config_hash->{code}->{define_sub};
	my $parameter = $config_hash->{code}->{parameter};
	my $list_of_apis = $config_hash->{get_api_types};
	my $config = $config_hash->{config};
	my $do_something_verb = $base . '_action';
	my $return_undef_unless = $config_hash->{code}->{return_undef_unless};
	my $dereference = $config_hash->{code}->{dereference};

	# generates the set for the $base
	foreach (@$list_of_apis) {

	#	my $old = lc $_;
		$_ = $make_sub_like->($_);
	#	$logger->fatal(sprintf('make_sub_like results: %s', $_));
	#	$parameter_hash->{$_} = $old;
		$package_code->{$_} = sprintf(

		$define_sub->(
			'$set->(' . $parameter->(0) . ', %s => $me->());'. "\n" .
			"\t".'shift;'
		), $_, $base, $_, )}

	foreach my $base_key (keys(%$config)) {
		$logger->fatal(sprintf('foreach parameter in api: %s', $base_key));
		# this is to get the first set of keys
		$package_code->{$base_key} = sprintf(

				$define_sub->(
					'$set->(' . $parameter->(0) . ', %s => $me->());'. "\n" .
					"\t" .'$_[0]->send;'
				), 
				$base_key, $do_something_verb, $base_key, );

		# get everything else
		my $h = $config->{$base_key};
		foreach (keys(%$h)) {

			# 'fields' is ignored (coinbase)
			next if ($_ eq 'fields');

			#permissions currently ignored (coinbase)
			next if ($_ eq 'permissions');

			#do not process this (coinbase) # still needed to process the method
			my $do_not_process; #$do_not_process = 1 if ($_ eq 'request');

			my $category = $_; #parameter||query_parameters(coinbase) # doing this a better way below
			my $cp = $h->{$_};

			# this function processes each item in list/hash/hashlist/listhash
			my $c; $c = sub {

				# this next section makes sure we don't have an array or hash. todo: finish so it only works on scalars
				if (($_[1]) && ($_[1] eq 'category')) {$category = $_[0]; return}
				my $cp = shift;
				if (ref($cp) && (ref($cp) eq $array)) { 
					foreach (@{$cp}) {$c->($_)}
				}
				elsif (ref($cp) && (ref($cp) eq $hash)) {
					foreach (keys(%{$cp})) {$c->($_); $c->($cp->{$_})}
				}				
				else {


					# process method is uc (coinbase)
					do {$method_hash->{$base_key} = $_; return} if ($_ eq uc($_));

					# parameters will be subroutines, must make sure name is legal
					my $old_parameter_name = $cp; 
					$cp = $make_sub_like->($cp); 
					$_ = $cp; 
					$parameter_hash->{$_} = $old_parameter_name unless ($old_parameter_name eq $cp) || (substr($old_parameter_name, 0, 1) eq '$') || (substr($old_parameter_name, 0, 1) eq '/');

					# process path as a path; store old_parameter_name as value for this.group of parameters
					do {$path_hash->{$base_key} = $old_parameter_name; return} if ($old_parameter_name =~ /^\//);

					# do not process if $old_parameter_name ... (coinbase)
					#$do_not_process = 1 if (substr($old_parameter_name, 0, 1) eq '$');

					# skip processing for this reason
					return if $do_not_process;

					my $parameter_sub_name = "set_" . $_;

					unless ($package_code->{$parameter_sub_name}) {
						$package_code->{$parameter_sub_name} = sprintf(
							
							$define_sub->(
								$return_undef_unless->('$get->(' . $parameter->(0) . ' => "api")') . 
								"\t".'$set->(' . $parameter->(0) . ', $me->() => ' . $parameter->(1) .');'
							), 
							$parameter_sub_name, );


						$package_code->{$_} = sprintf(

							$define_sub->(
								'return (' . '$get->(' . $parameter->(0) . $dereference->('$me->()') . ', $me->()) || undef);'
							), 
							$_, $_, );	
					}
				}
			};

			# START!
			$c->($cp);

		}

	}

	$config_hash->{output}->{package_code} = $package_code;
	$config_hash->{output}->{method_hash} = $method_hash;
	$config_hash->{output}->{path_hash} = $path_hash;
	$config_hash->{output}->{parameter_hash} = $parameter_hash;	
}

sub write_generated_code {
	my ($config_hash) = (@_);

	my $TEST = $config_hash->{output_file};

	my $base_package_name = "Toyhouse";
	my $package_sep = $config_hash->{package_sep};
	my $package_path_list = $config_hash->{package_path};
	my $package = join ($package_sep, $base_package_name, @$package_path_list);
	my $name_package_code = "package $package";

	my $warnings_and_strict = $config_hash->{code}->{warnings_and_strict};
	my $define_anon_sub = $config_hash->{code}->{define_anon_sub};
	my $iam_from_caller = $config_hash->{code}->{iam_from_caller};
	my $define_sub = $config_hash->{code}->{define_sub};
	my $read_only = $config_hash->{readonly};

	my $package_code = $config_hash->{output}->{package_code};
	my $path_hash = $config_hash->{output}->{path_hash};
	my $parameter_hash = $config_hash->{output}->{parameter_hash};
	my $method_hash = $config_hash->{output}->{method_hash};	

	#### Begin output of package. We sort the keys for human eyes only. ####
	print $TEST $name_package_code . ";\n";
	print $TEST $warnings_and_strict ."\n";

	#variable declaration

	print $TEST 'my Readonly $client = sub {Toyhouse::Client->new_session(@_)};' . "\n\n"; # ->send("GET" => "/orders?status=open")

	print $TEST sprintf(

		$define_anon_sub->(@$iam_from_caller[0] . @$iam_from_caller[1]), '$me') . "\n";


	print $TEST sprintf(

		$define_anon_sub->(
	q\my $self = shift; 
		my ($r, $delete_chain_flag) = (undef, 1); 
		my ($opts, $location) = ('opts', 'location');
		my $optl = "$opts" . "_" . "$location";
		$self->{$opts} = {} unless $self->{$opts}; 
		$self->{$optl} = {} unless $self->{$optl};
		my $p = shift; #parameter

		unless ($p =~ /(api|api_action)/) {
			if ($p =~ /(body|path|query)/) {$r = $self->{$optl}; $r->{$1} = [] unless $r->{$1}}
			else {
				$r = $self->{$opts};
				#allow chaining
				undef $delete_chain_flag; $self->{set_chain} = $p;
			}
			push @{$r->{$p}}, shift
		}
		else {$self->{$p} = $_[0]}
		delete $self->{set_chain} if ($self->{set_chain} && $delete_chain_flag);
		$self;\), 
		'$set',) . "\n";


	print $TEST sprintf(

		$define_anon_sub->(
	q\return undef unless scalar(@_) >= 2;
		my $r = shift;
		unless ($_[0] =~ /api_action|api/) {
			if ($_[0] eq 'query') {my $q = shift(@_); $r = $r->{opts}->{$q}}
			else {$r = $r->{opts}}
		}
		return $r->{$_[0]};\), 
		'$get',) . "\n";



	print $TEST sprintf(

		$define_anon_sub->(
	q\$_[0]->{set_chain} ? $_[0]->{set_chain} : $_[1];\), 
		'$_opts_location',) ."\n";



	foreach ('query','path','body') {
		print $TEST sprintf(

			$define_sub->(
	q\return undef unless ($_[0]->{api}); 
			my $p = $_opts_location->($_[0], $me->());
			$set->($_[0], $me->() => $p =>);\), 
		$_,) ."\n";
	}


	print $TEST 'my '. $read_only . ' $method = {';
	foreach my $base_key (sort(keys(%$method_hash))) {
		print $TEST sprintf("\n\t%s => '%s',", $base_key, $method_hash->{$base_key})
	}
	print $TEST "\n" .'};'. "\n\n";


	print $TEST 'my '. $read_only . ' $path = {';
	foreach my $base_key (sort(keys(%$path_hash))) {
		print $TEST sprintf("\n\t%s => '%s',", $base_key, $path_hash->{$base_key})
	}
	print $TEST "\n" .'};'. "\n\n";


	print $TEST 'my '. $read_only . ' $old_parameter_name = {';
	foreach my $base_key (sort(keys(%$parameter_hash))) {
		print $TEST sprintf("\n\t%s => '%s',", $base_key, $parameter_hash->{$base_key})
	}
	print $TEST "\n" .'};'. "\n\n";




	#subroutine declarations
	print $TEST sprintf(

		$define_sub->(
			'my $self = shift;' . "\n" .
			"\t". 'bless {session => $client->(@_)}, $self;' #my $self = shift; $client->(@_);'
		),
		'new', '%') ."\n";


	print $TEST sprintf(

		$define_sub->(
	q\my $self = shift;

	my $opts = $self->{opts} || undef;
	my $opts_location = $self->{opts_location} || undef;

	my $api_action = $self->{api_action};
	my $api = $self->{api};

	my $s = $self->{session};
	my $m = $method->{$api_action};
	my $p = $path->{$api_action};

	my ($body, $b);

	my $opts_key_list = [keys($opts_location)];

	if (keys(%s)) {
		# This sort is to make sure path is done before query (required!!)
		foreach my $q (sort(@$opts_key_list)) {

			if (($opts_location->{$q}) && (scalar(@{$opts_location->{$q}}) >= 1)) {
				my $opts_array_hash = $opts_location->{$q};

				if ($q =~ /(path|query)/) {
					$p .= '?' if ($1 eq 'query');
					my $string_maker = sub {if ($_[0] eq 'query') {return $_[2] . '=' . $_[1] . '&'} else {return '/' . $_[1]}};

					foreach my $key (@{$opts_array_hash}) {
						foreach (@{$opts->{$key}}) {
							$p .= $string_maker->(
								$1, 
								# We swap in $old_parameter_name here because we changed it earlier
								($old_parameter_name->{$_} || $_), 
								$key,);
						}
					}
				}
				elsif ($q eq 'body') {
					foreach my $key (@{$opts_array_hash}) {
						foreach (@{$opts->{$key}}) {
							$body->{$key} = $_;
						}
					}
					$b = $body
				}
			}
		}
	} #opts doesn't exist, a pitty, make sure this is a resend: m, p, are undef
	elsif (!defined($m) && !defined($p)) {
		# reusing the last request 
		$m = $self->{last_request_cache}->{method};
		$p = $self->{last_request_cache}->{path};
		$b = $self->{last_request_cache}->{body};
	}

	$self->{last_request_cache} = {method => $m, path => $p, body => $b} if keys(%s);
	%s = (); %s = ();

	if ($api eq 'ws') {
		return $Toyhouse::Client::new_websocket_session->($s, $b);
	}
	else {
		return $Toyhouse::Client::send->($s, $m, $p, $b);
	}\),
	'send', '%$opts', '%$opts', '%$opts_location', '%$opts') ."\n";

	#main subs
	foreach (sort(keys(%$package_code))) {print $TEST $package_code->{$_} ."\n"}

	print $TEST "\n1;\n";
	close $TEST;
}

sub main {
	my $config = generate_config();
	generate_code($config);
	write_generated_code($config);	
}

main();

1;