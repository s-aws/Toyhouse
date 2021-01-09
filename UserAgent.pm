package Toyhouse::UserAgent;
use Readonly;
use Time::HiRes qw/sleep/;
use Mojo::Base qw/-strict -signatures/;
use Mojo::UserAgent;
use Class::Struct ('Toyhouse::UserAgent' => {
	signer => 'Toyhouse::Signer',
	ua => 'Mojo::UserAgent',
	fastball => '$',

});

sub build($self) {
	$self->ua( Mojo::UserAgent->new() ) unless $self->ua();

	$self->ua->on(start => sub {
		my $public_sleep_time = (1 / 4.5); #public endpoint burst max
		my $private_sleep_time = (1 / 8); #private endpoint burst max

		if ($self->signer()) { 
#			sleep($private_sleep_time);
			$self->signer->sign($_[1]) 
		}
		else {
#			sleep($public_sleep_time)
		}

	});

	$self->ua->transactor->name('Toyhouse/Perl 0.9');
	return $self->ua;
}

1