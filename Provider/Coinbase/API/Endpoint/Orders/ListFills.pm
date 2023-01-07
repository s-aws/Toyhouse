package Toyhouse::Provider::Coinbase::API::Endpoint::Orders::ListFills;
use warnings;
use strict;
use Readonly;

Readonly::Scalar our $METHOD => Toyhouse::Provider::Generic::Request::Method->get;

sub api_endpoint {
        return [$METHOD, 'orders/historical/fills', 'ListFills'];
}

1
