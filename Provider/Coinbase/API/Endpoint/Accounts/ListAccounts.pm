package Toyhouse::Provider::Coinbase::API::Endpoint::Accounts::ListAccounts;
use warnings;
use strict;
use Readonly;

Readonly::Scalar our $METHOD => Toyhouse::Provider::Generic::Request::Method->get;

sub api_endpoint {
    return [$METHOD, 'accounts', 'ListAccount'];
}

1
