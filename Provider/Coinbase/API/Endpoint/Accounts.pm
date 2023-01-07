package Toyhouse::Provider::Coinbase::API::Endpoint::Accounts;
use warnings;
use strict;
use Readonly;
use Toyhouse::Provider::Coinbase::API::Endpoint::Accounts::GetAccount;
use Toyhouse::Provider::Coinbase::API::Endpoint::Accounts::ListAccounts;

Readonly::Scalar my $API => {
    GetAccount => $Toyhouse::Provider::Coinbase::API::Endpoint::Accounts::GetAccount::METHOD,
    ListAccounts => $Toyhouse::Provider::Coinbase::API::Endpoint::Accounts::ListAccounts::METHOD,
};

sub resource {
    'accounts'
}

sub method {
    $API->{$_[0]}
}

1
