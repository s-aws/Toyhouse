package Toyhouse::Model::UserAgent;
use Toyhouse::Signer;
use Mojo::Base qw/-strict -signatures/;
use Class::Struct ('UserAgent' => {
	url 			=> '$',
	subscription 	=> '%'
});

sub enable_signature ($self) {
	$self->on(start => Toyhouse::Signer::sign);
}