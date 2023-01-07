package Toyhouse::Provider::Coinbase::API::Endpoint::Orders::CancelOrders;
use warnings;
use strict;
use Readonly;

Readonly::Scalar our $METHOD => Toyhouse::Provider::Generic::Request::Method->post;

sub api_endpoint {
        return ['orders/batch_cancel', 'CancelOrders'];
}

1
