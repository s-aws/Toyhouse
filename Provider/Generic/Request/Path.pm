package Toyhouse::Provider::Generic::Request::Path;
use strict;
use warnings;
use Class::Struct 'Toyhouse::Provider::Generic::Request::Path' => {
    this => '@',
    query_params => 'Toyhouse::Provider::Generic::API::Query'};

our $PATH_SEPARATOR = '/';

sub as_string {
    my $path = join($PATH_SEPARATOR, @{$_[0]->this});

    if ($_[0]->query_params) {
        $path . $_[0]->query_params->as_path
    }
    else {
        $path
    }
}

1;