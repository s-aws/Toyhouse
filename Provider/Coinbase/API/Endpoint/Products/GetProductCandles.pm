package Toyhouse::Provider::Coinbase::API::Endpoint::Products::GetProductCandles;
use warnings;
use strict;
use Readonly;

Readonly::Scalar our $METHOD => Toyhouse::Provider::Generic::Request::Method->get;

sub api_endpoint {
        return ['products/{product_id}/candles', 'GetProductCandles'];
}

1
