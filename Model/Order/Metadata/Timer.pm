package Toyhouse::Model::Order::Metadata::Timer;
use Mojo::Base qw/-strict -signatures/;
use Mojo::IOLoop;
use Class::Struct ('Toyhouse::Model::Order::Metadata::Timer' => {
	canceled=> '$',
	filled	=> '$',
	match	=> '$',
	open	=> '$',
	received=> '$',
	done 	=> '$',

	canceled_id	=> '$',
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
	$self->filled($DEFAULT_SECONDS*$FILLED_ORDER_MULTIPLIER) unless $self->filled();
	$self->match($DEFAULT_SECONDS) 	unless $self->match();
	$self->open($DEFAULT_SECONDS*$OPEN_ORDER_MULTIPLIER) 	unless $self->open();
	$self->received($DEFAULT_SECONDS) unless $self->received();
	$self;
}

sub remove_all_timers($self) {
	Mojo::IOLoop->remove( $self->canceled_id()	)	if $self->canceled_id();
	Mojo::IOLoop->remove( $self->filled_id()	)	if $self->filled_id();
	Mojo::IOLoop->remove( $self->match_id()		)	if $self->match_id();	
	Mojo::IOLoop->remove( $self->open_id()		)	if $self->open_id();
	Mojo::IOLoop->remove( $self->received_id()	)	if $self->received_id();
	$self;
}

sub start_timer($self, $type, $coderef) {
	die "unable to call type $type" unless $self->$type(); my $typeid = $type . "_id";

	$self->$typeid(
		Mojo::IOLoop->singleton->reactor->timer( $self->$type() => $coderef )) if $type =~ /open|done|filled/;

	$self
}
1