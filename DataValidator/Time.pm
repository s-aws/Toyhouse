package Toyhouse::DataValidator::Time;
use DateTime;
use Mojo::Base qw/-strict -signatures/;
use Class::Struct ('Toyhouse::DataValidator::Time' => {
	time => '$',
	dt => 'DateTime',
	micro => '$'
});

my $EPOCH_FORMAT = '(\d+)(\.\d+)?';
my $ISO8601_FORMAT = '(\d+)\-(\d+)\-(\d+)T(\d+):(\d+):(\d+)\.(\d+).';

sub convert ($self) {
	if ( $self->time() =~ /^$ISO8601_FORMAT$/ ) {
		$self->dt( DateTime->new( year => $1, month => $2, day => $3, hour => $4, minute => $5, second => $6, time_zone => 'UTC') ); 
		$self->micro( $7 );
	}
	elsif ( $self->time() =~ /^$EPOCH_FORMAT$/ ) {
		$self->dt( DateTime->from_epoch( epoch => $1 ) );
	}

	return $self
}

sub to_epoch ($self) { $self->dt() ? $self->micro() ? $self->dt->epoch(). ".". $self->micro() : $self->time() : () }

1