package Toyhouse::Provider::Coinbase::Auth::Credentials;
use strict;
use warnings;

use Class::Struct 'Toyhouse::Provider::Coinbase::Auth::Credentials' => {
    api_key => '$',
    api_secret => '$'};

sub resolve {
    unless ($_[0]->api_key) {
        $_[0]->api_key($ENV{CB_KEY});
        $_[0]->api_secret($ENV{CB_SECRET});
    }
}


1;