package Toyhouse::Model::Coinbase::Product::Ticker;
use Readonly;
use Mojo::Base qw/-strict -signatures/;
use Class::Struct;

Readonly my $ELEMENTS => [qw/trade_id pirce size time bid ask volume/];

struct( 'Toyhouse::Model::Coinbase::Product::Ticker' => { map { $_ => '%' } @$ELEMENTS });

sub build($self) {
	use Data::Dumper;
	map { $_ => $self->$_() } @$ELEMENTS
}

1