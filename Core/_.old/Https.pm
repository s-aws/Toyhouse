package Toyhouse::Core::_::Https;
use warnings;
use strict;

BEGIN {require Toyhouse::Core::_::Https::config; require Net::HTTPS}

my $default_options = $Toyhouse::Core::_::Https::config::default_options;

my $options = sub {
	my $options = {};
	foreach my $key (keys %$default_options) {
		$options->{$key} = $default_options->{$key}[0]
	}
	$options->{Host} = shift . ':443' if $_[0];
	$options;
};

sub new_connection {
	my $opts = (scalar @_ == 2) ? $options->(pop(@_)) : undef;
	Net::HTTPS->new( %$opts);
}

1;