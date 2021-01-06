package Toyhouse::Coinbase::MarketData::Currencies;
use Readonly;
use Toyhouse::Model::Coinbase::API;
use Toyhouse::Coinbase::Request;
use Mojo::Base qw/-strict -signatures/;
use JSON qw/decode_json/;
use Class::Struct ('Toyhouse::Coinbase::MarketData::Currencies' => {
	currencies => '@',
	req => 'Toyhouse::Coinbase::Request'
});

Readonly my $GET => 'GET';

sub build($self) {
	$self->req( Toyhouse::Coinbase::Request->new->build() ) unless $self->req();
	return $self
}

sub update_currencies ($self) {
	$self->req->api_path( Toyhouse::Model::Coinbase::API->currencies() );
	$self->req->method( $GET );
	my $content = $self->req->send();

	die $content->asset->{content} unless $content->headers->header('content-length') >= 2; # {}

	$self->currencies( decode_json($content->asset->{content}) );
	$self;
}


1