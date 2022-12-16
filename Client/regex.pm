package Toyhouse::Client::regex;
use warnings;
use strict;

BEGIN {require Toyhouse::Core}

my ($exact,$name_separator) = ($Toyhouse::Core::EXACT, $Toyhouse::Core::NAME_SEPARATOR);
my ($hkw => $hexadecimal, $akw => $alphanumeric) = ('hex' => '[[:xdigit:]]', 'alnum' => '[[:alnum:]]'); # supported regex goes here (moving to json later)
my $has_number_of_parameters = sub {$Toyhouse::Core::has_number_of_parameters->(@_)};

sub build {
	return undef unless $has_number_of_parameters->(2, @_);

	my $regex = {};	my $with = {begins => '^', ends => '$', nothing => ''};
	my $generator = {
		$exact => sub {join(
				$with->{nothing}, 
				$with->{begins}, shift, 
				'+', $with->{ends})},};

	my ($action, $pattern) = (@_);
	if ($action eq $exact) {return $generator->{$exact}->($pattern)}
}

# build the regex hash here
my $regex = {	$exact . $name_separator . $hkw	=> build($exact => $hexadecimal),
				$exact . $name_separator . $akw	=> build($exact => $alphanumeric),};

# no longer needed
undef *build;

my $is_only = sub {my $key = $exact . $name_separator . $_[0]; return undef unless $has_number_of_parameters->(2, @_) && defined($regex->{$key}) && ($_[1] =~ m/$regex->{$key}/i); 1};
our $is_only_hexadecimal = 	sub {$is_only->($hkw 	=> @_)};
our $is_only_alphanumeric = sub {$is_only->($akw 	=> @_)};

1;