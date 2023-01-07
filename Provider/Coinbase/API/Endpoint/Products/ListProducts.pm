package Toyhouse::Provider::Coinbase::API::Endpoint::Products::ListProducts;
use warnings;
use strict;
use Readonly;

Readonly::Scalar our $METHOD => Toyhouse::Provider::Generic::Request::Method->get;

sub api_endpoint {
        return ['products', 'ListProducts'];
}

1
