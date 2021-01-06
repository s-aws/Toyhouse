package Toyhouse::Orderbooks;
use Mojo::Base qw/-strict -signatures/;
use Toyhouse::Order::Book;
use Class::Struct ('Toyhouse::Orderbooks' => {
	product_ids => '@',
	book => '%',
});
# This is a singleton that contains all order books
#product_ids->('BTC-USD')->order( Toyhouse::Model::Order->new( $order )->build );
sub build($self) {
	$self->book( $_ => Toyhouse::Order::Book->new(product_id => $_) ) foreach @{ $self->product_ids };
	$self->product_ids([]);
	$self
}

1