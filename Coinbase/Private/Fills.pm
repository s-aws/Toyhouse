package Toyhouse::Coinbase::Private::Fills;
use Readonly;
use Toyhouse::Model::Coinbase::API;
use Toyhouse::Coinbase::Request;
use Toyhouse::Model::Order;
use Mojo::Base qw/-strict -signatures/;
use JSON qw/decode_json/;
use Class::Struct ('Toyhouse::Coinbase::Private::Fills' => {
	req => 'Toyhouse::Coinbase::Request'
});

Readonly my $GET => 'GET';

sub build($self) {
	$self->req( Toyhouse::Coinbase::Request->new->build() ) unless $self->req();
	$self;
}

sub update_fills ($self, $query_param='product_id=BTC-USD') { # 'product_id=BTC-USD' | 'order_id=2ed2b531-3672-4389-97fd-2b2c5578dccb'
	die 'product_id or order_id is required' unless $query_param;
	$self->req->api_path( Toyhouse::Model::Coinbase::API->orders() );
	$self->req->query_parameters([ $query_param ]);
	$self->req->method( $GET );
	my $content = $self->req->send();

	die $content->asset->{content} unless $content->headers->header('content-length') >= 2; # []

	return $content->asset->{content};
	$self
}