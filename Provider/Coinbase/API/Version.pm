package Toyhouse::Provider::Coinbase::API::Version;
use strict;
use warnings;
use Class::Struct 'Toyhouse::Provider::Coinbase::API::Version' => {
    this => '$'
};

sub default_version {
    '2022-12-17'
}

sub to_dict {
    {'CB-VERSION' => $_[0]->to_string}
}

sub to_string {
    $_[0]->this(default_version) unless $_[0]->this;
    $_[0]->this
}

1;
