package Toyhouse::Provider::Coinbase::Request::Path;
use strict;
use warnings;
use Toyhouse::Provider::Generic::Request::Path;
use Class::Struct 'Toyhouse::Provider::Coinbase::Request::Path' => {
    this => '@',
    query_params => 'Toyhouse::Provider::Generic::API::Query'};

*as_string = *Toyhouse::Provider::Generic::Request::Path::as_string;

1;