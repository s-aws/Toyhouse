package Toyhouse::Coinbase::Private::Deposits;
use Readonly;
use Toyhouse::Model::Coinbase::API;
use Toyhouse::Coinbase::Request;
use Toyhouse::Model::Order;
use Mojo::Base qw/-strict -signatures/;
use JSON qw/decode_json/;
use Class::Struct ('Toyhouse::Coinbase::Private::Deposits' => {
	req => 'Toyhouse::Coinbase::Request'
});

Readonly my $GET => 'GET';

sub build($self) {
	$self->req( Toyhouse::Coinbase::Request->new->build() ) unless $self->req();
	$self;
}

sub update_deposits ($self) { 
	my $type_param='type=deposit';
	$self->req->api_path( Toyhouse::Model::Coinbase::API->deposits() );
	$self->req->query_parameters([ $type_param ]);	
	$self->req->method( $GET );
	my $content = $self->req->send();

	die $content->asset->{content} unless $content->headers->header('content-length') >= 2; # []

	return $content->asset->{content};
	$self
}

sub update_deposit ($self, $transfer_id) { 
	$self->req->api_path( Toyhouse::Model::Coinbase::API->deposits(':'. $transfer_id) );
	$self->req->method( $GET );
	my $content = $self->req->send();

	die $content->asset->{content} unless $content->headers->header('content-length') >= 2; # []

	return $content->asset->{content};
	$self
}

sub update_payment_method ($self, $param) { # {amount => 1.0, currency => 'USD', payment_method_id => 'payment-method-id'}
	$self->req->api_path( Toyhouse::Model::Coinbase::API->deposits('payment-method') );
	$self->req->method( $GET );
	$self->req->body( $param );
	my $content = $self->req->send();

	die $content->asset->{content} unless $content->headers->header('content-length') >= 2; # []

	return $content->asset->{content};
	$self
}