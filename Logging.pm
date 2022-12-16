package Toyhouse::Logging;
use warnings;
use strict;

BEGIN {
	require Log::Log4perl; 	import Log::Log4perl qw(:easy)
}

Log::Log4perl->easy_init($ERROR);

sub new {
	Log::Log4perl->get_logger(shift);
}

1;