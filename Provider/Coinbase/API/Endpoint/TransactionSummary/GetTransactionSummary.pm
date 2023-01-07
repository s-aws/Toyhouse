package Toyhouse::Provider::Coinbase::API::Endpoint::TransactionSummary::GetTransactionSummary;
use warnings;
use strict;
use Readonly;

Readonly::Scalar our $METHOD => Toyhouse::Provider::Generic::Request::Method->get;

sub api_endpoint {
        return [$METHOD, 'transaction_summary', 'GetTransactionSummary'];
}

1
