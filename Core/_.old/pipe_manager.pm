package Toyhouse::Core::_::pipe_manager;
use warnings;
use strict;

#
##
## my $pipe = 	new Toyhouse::Core::_::pipe_manager;
## my $id 	=	create $pipe;
## my $read_pipe	= get_read $pipe $id;
## my $write_pipe 	= get_write $pipe $id;
## Todo
## my $close_read 	= close_read $pipe $id;
## my $close_write 	= close_write $pipe $id;
## my $close_both 	= close $pipe $id;
## my $close_all 	= close $pipe;
##
#

BEGIN {require Toyhouse::Core}

my $counter = 		$Toyhouse::Core::PIPE_MANAGER_COUNTER_NAME;
my $default_value = $Toyhouse::Core::FIRST_ITEM_IN_LIST;
my $io = 	$Toyhouse::Core::IO_CONSTANT;
my $name = 	$Toyhouse::Core::PIPE_MANAGER_NAME;
my $pipe_default_state = 	$Toyhouse::Core::PIPE_MANAGER_DEFAULT_CREATE_STATE;
my $pipe_increase_amount = 	$Toyhouse::Core::PIPE_MANAGER_PIPE_INCREASE_AMOUNT;
my $reader_name = $Toyhouse::Core::PIPE_MANAGER_READER_NAME;
my $writer_name = $Toyhouse::Core::PIPE_MANAGER_WRITER_NAME;

my $has_number_of_paramters = sub {$Toyhouse::Core::has_number_of_parameters->(@_)};
my $nonce = sub {$Toyhouse::Core::NONCE->()};

sub new {bless {$counter => $default_value}, shift}
sub create { 	# Pipe pair created and stored in the following hash location
				# self->{$pipe_default_state}->{$N}->{$type_name}
	my ($self, $R, $W) = (shift, undef, undef);
	if (pipe($R, $W)) {
		$self->{$counter} += $pipe_increase_amount;
		my $N = $nonce->();
		*$R{$io}->autoflush;
		*$W{$io}->autoflush;
		$self->{$pipe_default_state}->{$N} = { $reader_name => *$R{$io}, $writer_name => *$W{$io} };
		return $N}
	else {undef}}

sub get_read {
	return undef unless $has_number_of_paramters->(2, @_) && defined($_[0]->{$pipe_default_state}) && defined($_[0]->{$pipe_default_state}->{$_[1]});
	$_[0]->{$pipe_default_state}->{$_[1]}->{$reader_name}}

sub get_write {
	return undef unless $has_number_of_paramters->(2, @_) && defined($_[0]->{$pipe_default_state}) && defined($_[0]->{$pipe_default_state}->{$_[1]});
	$_[0]->{$pipe_default_state}->{$_[1]}->{$writer_name}}

#sub close {
#	my ($self, $pipe_id, $action) = (@_);
#	return undef unless defined($self->{$pipe_default_state});
#}
1;