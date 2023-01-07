package Toyhouse::Provider::Coinbase::API::Endpoint::Orders;
use warnings;
use strict;
use Readonly;
use Toyhouse::Provider::Coinbase::API::Endpoint::Orders::CreateOrder;
use Toyhouse::Provider::Coinbase::API::Endpoint::Orders::CancelOrders;
use Toyhouse::Provider::Coinbase::API::Endpoint::Orders::ListOrders;
use Toyhouse::Provider::Coinbase::API::Endpoint::Orders::ListFills;
use Toyhouse::Provider::Coinbase::API::Endpoint::Orders::GetOrder;

Readonly::Scalar my $API => {
    CreateOrder => $Toyhouse::Provider::Coinbase::API::Endpoint::Orders::CreateOrder::METHOD,
    CancelOrder => $Toyhouse::Provider::Coinbase::API::Endpoint::Orders::CancelOrder::METHOD,
    ListOrders => $Toyhouse::Provider::Coinbase::API::Endpoint::Orders::ListOrders::METHOD,
    ListFills => $Toyhouse::Provider::Coinbase::API::Endpoint::Orders::ListFills::METHOD,
    GetOrder => $Toyhouse::Provider::Coinbase::API::Endpoint::Orders::GetOrder::METHOD,
};

sub resource {
    'orders'
}

sub method {
    $API->{$_[0]}
}

1
