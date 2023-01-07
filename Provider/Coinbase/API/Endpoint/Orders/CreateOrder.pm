package Toyhouse::Provider::Coinbase::API::Endpoint::Orders::CreateOrder;
use warnings;
use strict;
use Readonly;

Readonly::Scalar our $METHOD => Toyhouse::Provider::Generic::Request::Method->post;

sub api_endpoint {
        return ['orders', 'CreateOrder'];
}

1
