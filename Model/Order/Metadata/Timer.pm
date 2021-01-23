package Toyhouse::Model::Order::Metadata::Timer;
use Mojo::Base qw/-strict -signatures/;
use Mojo::IOLoop;
use Class::Struct ('Toyhouse::Model::Order::Metadata::Timer' => {
	canceled=> '$',
	remainok=> '$', # this is to check if remaining_size is > minimum allowed
	filled	=> '$',
	match	=> '$',
	open	=> '$',
	received=> '$',
	done 	=> '$',

	canceled_id	=> '$',
	remainok_id	=> '$',	
	filled_id	=> '$',
	match_id	=> '$',
	open_id		=> '$',
	received_id	=> '$',
	done_id 	=> '$',	 # previous done event timer

});

our $DEFAULT_SECONDS = 60;
our $FILLED_ORDER_MULTIPLIER = 2; # order has just been filled timer
our $OPEN_ORDER_MULTIPLIER = 60; # open order with timer to cancel

sub build($self) {
	$self->canceled($DEFAULT_SECONDS) unless $self->canceled();
	$self->remainok($DEFAULT_SECONDS) unless $self->remainok();	
	$self->filled($DEFAULT_SECONDS*$FILLED_ORDER_MULTIPLIER) unless $self->filled();
	$self->match($DEFAULT_SECONDS) 	unless $self->match();
	$self->open($DEFAULT_SECONDS*$OPEN_ORDER_MULTIPLIER) 	unless $self->open();
	$self->received($DEFAULT_SECONDS) unless $self->received();
	$self->done($DEFAULT_SECONDS) unless $self->done();	
	$self;
}

sub remove($self, $id) {
	Mojo::IOLoop->remove( $self->$id() ) if $self->$id();
}

sub remove_all_timers($self) {
	$self->remove( $_ ) foreach qw/canceled_id filled_id match_id open_id received_id remainok_id done_id/;
	$self;
}

sub start_timer($self, $type, $coderef) {
	die "unable to call type $type" unless $self->$type(); my $typeid = $type . "_id";

	$self->$typeid(
		Mojo::IOLoop->singleton->reactor->timer( $self->$type() => $coderef )) if $type =~ /canceled|remainok|filled|match|open|received|done/;

	$self
}

sub start_recurring_timer($self, $type, $coderef) {
	die "unable to call type $type" unless $self->$type(); my $typeid = $type . "_id";

	$self->$typeid(
		Mojo::IOLoop->singleton->reactor->recurring( $self->$type() => $coderef )) if $type =~ /canceled|remainok|filled|match|open|received|done/;

	$self
}
1