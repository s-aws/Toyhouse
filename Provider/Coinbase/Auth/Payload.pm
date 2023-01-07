package Toyhouse::Provider::Coinbase::Auth::Payload;
use strict;
use warnings;
use Class::Struct 'Toyhouse::Provider::Coinbase::Auth::Payload' => {
    body => 'Toyhouse::Provider::Generic::Request::Body',
    method => '$',
    request_path => 'Toyhouse::Provider::Coinbase::Request::Path',
    timestamp => 'Toyhouse::Provider::Coinbase::Timestamp'
};

sub as_string {

    $_[0]->timestamp->as_string .
        $_[0]->method .
        "/" . $_[0]->request_path->build->as_string .
        $_[0]->body->to_string;
}

1;