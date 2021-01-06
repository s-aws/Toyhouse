package Toyhouse::Coinbase::MarketData;
use Readonly;
use Mojo::Base qw/-strict -signatures/;
use Class::Struct ('Toyhouse::Coinbase::MarketData' => {
	product => '%',
	product_book => '%',
	product_ticker => '%',
});

1