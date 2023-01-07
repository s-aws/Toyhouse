package Toyhouse::Provider::Coinbase::API::Endpoint::Orders::GetOrder;
use warnings;
use strict;
use Readonly;

Readonly::Scalar our $METHOD => Toyhouse::Provider::Generic::Request::Method->get;

sub api_endpoint {
        return ['orders/historical/{order_id}', 'GetOrder'];
}

1
