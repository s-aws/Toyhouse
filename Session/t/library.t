use strict;
use Test;

BEGIN { plan tests => 32, todo => [9, 16, 23 .. 26, 29 .. 32]}

use Readonly;
use Toyhouse::Auth::t::credentials;
use Toyhouse::Session::library;

print "# preparing tests for library.pm\n";

my Readonly $CREDENTIALS = 
{
	key			=> $Toyhouse::Auth::t::credentials::API_KEY,
	passphrase 	=> $Toyhouse::Auth::t::credentials::PASSPHRASE,
	secret 		=> $Toyhouse::Auth::t::credentials::API_SECRET
};

my Readonly $BAD_KEY_CREDENTIALS = 
{
	key			=> undef,
	passphrase 	=> $Toyhouse::Auth::t::credentials::PASSPHRASE,
	secret 		=> $Toyhouse::Auth::t::credentials::API_SECRET
};

my Readonly $BAD_PASSPHRASE_CREDENTIALS = 
{
	key			=> $Toyhouse::Auth::t::credentials::API_KEY,
	passphrase 	=> undef,
	secret 		=> $Toyhouse::Auth::t::credentials::API_SECRET
};

my Readonly $BAD_SECRET_CREDENTIALS = 
{
	key			=> $Toyhouse::Auth::t::credentials::API_KEY,
	passphrase 	=> $Toyhouse::Auth::t::credentials::PASSPHRASE,
	secret 		=> undef
};

my Readonly $MISSING_SECRET_CREDENTIALS = 
{
	key			=> $Toyhouse::Auth::t::credentials::API_KEY,
	passphrase 	=> $Toyhouse::Auth::t::credentials::PASSPHRASE
};


my $test_actions = sub {
	my $session_key;

 	# Cannot continue unless we have two arguments
	die 'test requires two arguments' unless scalar(@_) == 2;
	my $commands = shift;
	my $creds = shift;
	foreach my $action (@$commands) {
		print "# $action ";

		if ($action eq 'store') {
			print "key: $CREDENTIALS->{key} ";

			# 1
			ok(	$session_key = Toyhouse::Session::library->credential($action => $creds) );
			print "# session_key: $session_key\n";
		}

		elsif (($action eq 'retrieve') && $session_key) {
			my $creds;

			# 2
			ok ( $creds = Toyhouse::Session::library->credential($action => $session_key) );

			# 3
			skip( ref($creds) ne 'HASH',
				sub {

					#4
					ok ( $creds->{key} ne undef );

					#5
					ok ( $creds->{passphrase} ne undef );

					#6
					ok ( $creds->{secret} ne undef );			
				}
			);

			undef $session_key;
		}
		else {
			print "key: $CREDENTIALS->{key} ";
			ok(	$session_key = Toyhouse::Session::library->credential($action => $creds) );
			print "# session_key: $session_key\n";
		}
	}
};

$test_actions->(['store', 'retrieve'], $CREDENTIALS);
print "# we expect failures here\n"; 
$test_actions->(['store', 'retrieve'], $BAD_KEY_CREDENTIALS);
$test_actions->(['store', 'retrieve'], $BAD_PASSPHRASE_CREDENTIALS);
$test_actions->(['store', 'retrieve'], $BAD_SECRET_CREDENTIALS);
$test_actions->(['storebad', 'retrieve'], $CREDENTIALS);
$test_actions->(['store', 'retrieve'], {});
print "# done\n";

1;
