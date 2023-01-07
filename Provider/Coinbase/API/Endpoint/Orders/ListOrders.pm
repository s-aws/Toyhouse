package Toyhouse::Provider::Coinbase::API::Endpoint::Orders::ListOrders;
use warnings;
use strict;
use Readonly;

Readonly::Scalar our $METHOD => Toyhouse::Provider::Generic::Request::Method->get;

sub api_endpoint {
        return [$METHOD, 'orders/historical/batch', 'ListOrders'];
}

1
