package Toyhouse::Session;
use warnings;
use strict;
#
##  credential hash is passed to $session in key => credential_hash form
##  $auth = {secret => $secret, passphrase => $passphrase, key => $key}
##
## 	my $session = new Toyhouse::Session auth => $auth;
##  $session contains:
##  {
##		$session_name 			=> $me,
##		$session_cred_type_key 	=> $credential_type,
##		$session_key_name		=> $session_key
##	}
#

BEGIN {require Toyhouse::Core; require Toyhouse::Session::library}

my $library_store_command 	=	$Toyhouse::Core::LIBRARY_STORE_COMMAND;
my $library_get_command		=	$Toyhouse::Core::LIBRARY_GET_COMMAND;
my $session_name			=	$Toyhouse::Core::SESSION_NAME;
my $session_cred_type_key	=	$Toyhouse::Core::SESSION_CRED_TYPE;
my $session_key_name		=	$Toyhouse::Core::SESSION_KEY;


my $me = 'session'; 

sub new {
	my (undef, $credential_type, $credential_hash) = (@_);

	my $session_key = credential Toyhouse::Session::library $library_store_command 	=> $credential_hash;
#	my $auth_info 	= credential Toyhouse::Session::library $library_get_command 	=> $session_key;

	my $session_info = {
		$session_name 			=> $me,
		$session_cred_type_key 	=> $credential_type,
		$session_key_name		=> $session_key
	};
	$session_info;
}

sub get {
	return credential Toyhouse::Session::library $library_get_command 	=> $_[1];	
}
1;