package Toyhouse::Provider::Generic::API::Endpoint;
use strict;
use warnings;

sub as_string {
    join(path_separator(), (base_url(), @$_[0]->this))
}

1;