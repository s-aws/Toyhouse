package Toyhouse::Provider::Generic::Timestamp;
use strict;
use warnings;

sub get_new_time {
    CORE::time()
}

sub renew {
    $_[0]->{time} = get_new_time();
}

sub as_string {
    $_[0]->{time}
}

1;