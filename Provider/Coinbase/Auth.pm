package Toyhouse::Provider::Coinbase::Auth;
use warnings;
use strict;
use Toyhouse::Provider::Coinbase::Auth::Signer;
use Class::Struct 'Toyhouse::Provider::Coinbase::Auth' => {
    credentials => 'Toyhouse::Provider::Coinbase::Auth::Credentials',
    payload => 'Toyhouse::Provider::Coinbase::Auth::Payload'};

sub __refresh {
    $_[0]->credentials->resolve;
    $_[0]->payload->timestamp->renew;
}

sub generate_request_signature_headers {

    __refresh($_[0]);

    {
        "CB-ACCESS-KEY" => $_[0]->credentials->api_key,
        "CB-ACCESS-SIGN" => Toyhouse::Provider::Coinbase::Auth::Signer->new(
                                    secret => $_[0]->credentials->api_secret,
                                    payload => $_[0]->payload->as_string)->sign,
        "CB-ACCESS-TIMESTAMP" => $_[0]->payload->timestamp->as_string};
}

1;