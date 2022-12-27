package Toyhouse::Provider::Generic::Request::Body;
use strict;
use warnings;
use Class::Struct 'Toyhouse::Provider::Generic::Request::Body' => {
    this => '$'
};

sub to_string {
    $_[0]->this || '' # need to verify () won't work
}

1;