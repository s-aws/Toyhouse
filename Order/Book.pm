package Toyhouse::Order::Book;
use Mojo::Base qw/-strict -signatures/;
use Class::Struct ('Toyhouse::Order::Book' => {
	product_id => '$',
	order => 'Toyhouse::Model::Order'
});
# This contains a single order book
1