package Toyhouse::Provider::Coinbase::Request::Path;
use strict;
use warnings;
use Toyhouse::Provider::Generic::Request::Path;
use Class::Struct 'Toyhouse::Provider::Coinbase::Request::Path' => {
    this => '@',
    query_params => 'Toyhouse::Provider::Generic::API::Query'};

my $BASE_PATH = sub {('api', 'v3', 'brokerage')};

*as_string = *Toyhouse::Provider::Generic::Request::Path::as_string;

sub build {
    my $current = $_[0]->this;
    my @base_path = $BASE_PATH->();

    unless (${$current}[0] eq $base_path[0]) {
        while (my $element = pop(@base_path)) {
            unshift(@{$current}, $element)
        }
    }

    $_[0];
}

1;