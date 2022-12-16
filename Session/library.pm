package Toyhouse::Session::library;
use warnings;
use strict;

#
##  
##  store credentials in the library. return $library_card, used to get the credentials back
##	my $library_card = credential Toyhouse::Session::library $library_store_command 	=> $credential_hash;
##  or Toyhouse::Session::library->credential($library_store_command => $credential_hash)
##  whichever you  fancy
##
##  retrieve the credential from the library
##	my $auth_info 	= credential Toyhouse::Session::library $library_get_command 	=> $library_card;
##
## Credential hash format
## 
##	'store' || 'retrieve',
## 	{
##          'key' => '<key>',
##          'passphrase' => '<passphrase>',
##          'secret' => '<secret>'
##  }
## 
##
#

BEGIN {require Toyhouse::Core}

my $api = 		$Toyhouse::Core::PRO_COINBASE_API_AUTH_KW;
my $auth_keys = $Toyhouse::Core::PRO_COINBASE_API_AUTH_KEYS;

*encode_json =	*Toyhouse::Core::encode_json;

my $hmac_sha256_hex_w_nonce = *Toyhouse::Core::hmac_sha256_hex_w_nonce;
my $library_store_command =	$Toyhouse::Core::LIBRARY_STORE_COMMAND;
my $library_get_command =	$Toyhouse::Core::LIBRARY_GET_COMMAND;

sub credential {
	# credential storage
	# todo, encrypt credentials before storying with public key
	# todo, decrypt credentials on retrieval with private key 
	my (undef, $command, $credentials) = (shift, @_);

	# dictionary to store credentials
	CORE::state $AuthBook = {};	

	sub store {
		# input: %credential
		# output: retrieval_key

		my $credentials_hash = shift;
		my $credentials_key = $hmac_sha256_hex_w_nonce->( encode_json($credentials_hash));

		$AuthBook->{$credentials_key} = {%$credentials_hash};
		$credentials_key;	
	}

	sub retrieve {
		# input: retrieval_key
		# output: %credential

		$AuthBook->{$_[0]} ? $AuthBook->{$_[0]} : undef
	}

	if ($command eq $library_store_command) {store($credentials)}
	elsif ($command eq $library_get_command) {retrieve($credentials)}
}

1;