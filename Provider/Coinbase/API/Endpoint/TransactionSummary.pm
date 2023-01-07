package Toyhouse::Provider::Coinbase::API::Endpoint::TransactionSummary;
use warnings;
use strict;
use Readonly;
use Toyhouse::Provider::Coinbase::API::Endpoint::TransactionSummary::GetTransactionSummary;

Readonly::Scalar my $API => {
    GetTransactionSummary => $Toyhouse::Provider::Coinbase::API::Endpoint::TransactionSummary::GetTransactionSummary::METHOD,
};

sub resource {
    'transaction_summary'
}

sub method {
    $API->{$_[0]}
}

1;