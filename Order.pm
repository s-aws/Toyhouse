package Toyhouse::Order;
use Mojo::Base qw/-strict -signatures/;
use Class::Struct( 'Toyhouse::Order' => {
	order_type => 'Toyhouse::Model::Order'
});


1;