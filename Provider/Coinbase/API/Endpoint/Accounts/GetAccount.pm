package Toyhouse::Provider::Coinbase::API::Endpoint::Accounts::GetAccount;
use warnings;
use strict;
use Readonly;

Readonly::Scalar our $METHOD => Toyhouse::Provider::Generic::Request::Method->get;

sub api_endpoint {
        return ['accounts/:account_id', 'ListAccount'];
}

1
