package Toyhouse::Provider::Coinbase::Timestamp;
use strict;
use warnings;
use Toyhouse::Provider::Generic::Timestamp;

*get_new_time = *Toyhouse::Provider::Generic::Timestamp::get_new_time;
*renew = *Toyhouse::Provider::Generic::Timestamp::renew;
*as_string = *Toyhouse::Provider::Generic::Timestamp::as_string;

sub new {
    bless {time => get_new_time()}, shift
}

sub as_header {
    {'CB-ACCESS-TIMESTAMP' => $_[0]->as_string}
}

1;