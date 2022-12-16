package Toyhouse::Core::_::Https::config;
use warnings;
use strict;

our $default_options = {
	Host 			=> ['localhost:443'],
	KeepAlive 		=> [60, 1 .. 300],
	SendTE 			=> ['gzip'],
	HTTPVersion 	=> [1.1, 1.0],
	PeerHTTPVersion => [1.1, 1.0],
	MaxLineLength 	=> [0, 1 .. 65535],
	MaxHeaderLines 	=> [0, 1 .. 128]
};

1;