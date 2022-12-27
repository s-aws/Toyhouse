package Toyhouse::Provider::Coinbase::Auth::Signer;
use strict;
use warnings;
use Toyhouse::Provider::Generic::Auth::Secure;
use Class::Struct 'Toyhouse::Provider::Coinbase::Auth::Signer' => {
    secret => '$',
    payload => '$'};

our $BASE64_ENCODE_EOL = '';

*hmac_sha256_hex = *Toyhouse::Provider::Generic::Auth::Secure::hmac_sha256_hex;

sub sign {
    hmac_sha256_hex($_[0]->payload, $_[0]->secret);
}

1;