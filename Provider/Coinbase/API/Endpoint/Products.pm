package Toyhouse::Provider::Coinbase::API::Endpoint::Products;
use warnings;
use strict;
use Readonly;
use Toyhouse::Provider::Coinbase::API::Endpoint::Products::ListProducts;
use Toyhouse::Provider::Coinbase::API::Endpoint::Products::GetProduct;
use Toyhouse::Provider::Coinbase::API::Endpoint::Products::GetProductCandles;
use Toyhouse::Provider::Coinbase::API::Endpoint::Products::GetMarketTrades;

Readonly::Scalar my $API => {
    ListProducts => $Toyhouse::Provider::Coinbase::API::Endpoint::Products::ListProducts::METHOD,
    GetProduct => $Toyhouse::Provider::Coinbase::API::Endpoint::Products::GetProduct::METHOD,
    GetProductCandles => $Toyhouse::Provider::Coinbase::API::Endpoint::Products::GetProductCandles::METHOD,
    GetMarketTrades => $Toyhouse::Provider::Coinbase::API::Endpoint::Products::GetMarketTrades::METHOD,
};

sub resource {
    'products'
}

sub method {
    $API->{$_[0]}
}

1
