package Toyhouse::Provider::Coinbase::API::Endpoint;
use strict;
use warnings;
use Toyhouse::Provider::Coinbase::Configuration::REST;
use Class::Struct 'Toyhouse::Provider::Coinbase::API::Endpoint' => [
    this => 'Toyhouse::Provider::Coinbase::Request::Path',
];

our $BASE_URL = $Toyhouse::Provider::Coinbase::Configuration::REST::BASE_URL;
our $PATH_SEPARATOR = '/';

sub as_url {
    join($PATH_SEPARATOR, ($BASE_URL, $_[0]->this->build->as_string))
}

1;