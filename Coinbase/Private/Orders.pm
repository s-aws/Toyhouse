package Toyhouse::Coinbase::Private::Orders;
use Readonly;
use Toyhouse::Model::Coinbase::API;
use Toyhouse::Coinbase::Request;
use Toyhouse::Model::Order;
use Mojo::Base qw/-strict -signatures/;
use JSON qw/decode_json/;
use Class::Struct ('Toyhouse::Coinbase::Private::Orders' => {
	req => 'Toyhouse::Coinbase::Request',
});

Readonly my $GET => 'GET';
Readonly my $POST => 'POST';
Readonly my $DELETE => 'DELETE';

sub build($self) {
	$self->req( Toyhouse::Coinbase::Request->new->build() ) unless $self->req();
	$self;
}

sub place_new_order ($self, $order_ref) {
	die 'order hashref is required' unless $order_ref;
	$self->req->api_path( Toyhouse::Model::Coinbase::API->orders() );
	$self->req->body( $order_ref );
	$self->req->method( $POST );

	my $content = $self->req->send();

	die $content->asset->{content} unless $content->headers->header('content-length') >= 2; # []

	return $content->asset->{content};
	$self
}

sub cancel_order ($self, $order_id) {
	die 'order_id is required' unless $order_id;
	$self->req->api_path( Toyhouse::Model::Coinbase::API->orders($order_id) );
	$self->req->method( $DELETE );
	my $content = $self->req->send();

	die $content->asset->{content} unless $content->headers->header('content-length') >= 2; # []

	return $content->asset->{content};
	$self
}

sub cancel_all_orders ($self, $product_id=undef) { #'product_id=BTC-USD'
	$self->req->api_path( Toyhouse::Model::Coinbase::API->orders() );
	$self->req->query_parameters([$product_id]) if $product_id;
	$self->req->method( $DELETE );
	my $content = $self->req->send();

	die $content->asset->{content} unless $content->headers->header('content-length') >= 2; # []

	return $content->asset->{content};
	$self
}

sub update_order ($self, $order_id) {
	die 'order_id is required' unless $order_id;	
	$self->req->api_path( Toyhouse::Model::Coinbase::API->orders($order_id) );
	$self->req->method( $GET );

	my $content = $self->req->send();

	die $content->asset->{content} unless $content->headers->header('content-length') >= 2; # []

	return Toyhouse::Model::Order->new(%{ decode_json($content->asset->{content}) })->build;
	$self
}

sub update_orders ($self, @args) { #  'status=pending' || 'status=open' || 'status=active'

	$self->req->api_path( Toyhouse::Model::Coinbase::API->orders() );
	$self->req->query_parameters(\@args) if @args;
	$self->req->method( $GET );
	my $content = $self->req->send();

	die $content->asset->{content} unless $content->headers->header('content-length') >= 2; # []

	return $content->asset->{content};
	$self
}
1