package Toyhouse::Provider::Generic::API::Query;
use strict;
use warnings;
use Class::Struct 'Toyhouse::Provider::Generic::API::Query' => {
    this => '%'
};

sub as_path {
    my $path = [];
    my $query_dict = $_[0]->this;

    foreach ( sort(keys %$query_dict ) ) {
        push(@$path, "$_=" . %{$query_dict}{$_})
    }

    "?" . join("&", @$path)
}

1;