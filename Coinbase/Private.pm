package Toyhouse::Coinbase::Private;
use Readonly;
use Toyhouse::Model::Coinbase::API;
use Toyhouse::Coinbase::Request;
use Toyhouse::Model::Coinbase::Product;
use Toyhouse::Model::Coinbase::Product::Book;
use Mojo::UserAgent;
use Mojo::Base qw/-strict -signatures/;
use JSON qw/decode_json/;
use Class::Struct ('Toyhouse::Coinbase::Private' => {
	product => '%',
	product_book => '%',
	product_ticker => '%',
	signer => 'Toyhouse::Signer',
	req => 'Toyhouse::Coinbase::Request'
});

Readonly my $GET => 'GET';


1