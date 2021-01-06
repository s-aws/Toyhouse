package Toyhouse::Model::Order::Internal;
use Mojo::Base qw/-strict -signatures/;
use Exporter;

our @ISA 		= qw/Exporter/;
our @EXPORT 	= qw/to_percent product sum/;

sub product($x,$y) {$x * $y}
sub sum($x,$y) {$x+$y}
sub to_percent($x) {$x / 100}

1;