package Toyhouse::Provider::Coinbase::API::Endpoint::Products::GetProduct;
use warnings;
use strict;
use Readonly;

Readonly::Scalar our $METHOD => Toyhouse::Provider::Generic::Request::Method->get;

sub api_endpoint {
        return ['products/{product_id}', 'GetProduct'];
}

1
