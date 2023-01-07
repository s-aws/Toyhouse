package Toyhouse::Provider::Coinbase::API::Endpoint::Products::GetMarketTrades;
use warnings;
use strict;
use Readonly;

Readonly::Scalar our $METHOD => Toyhouse::Provider::Generic::Request::Method->get;

sub api_endpoint {
        return ['products/{product_id}/candles', 'GetMarketTrades'];
}

1
