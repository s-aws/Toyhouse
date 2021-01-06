package Toyhouse::Model::Coinbase::Product;
use Readonly;
use Mojo::Base qw/-strict -signatures/;
use Class::Struct;

Readonly my $ELEMENTS => [qw/base_currency status cancel_only min_market_funds post_only base_max_size limit_only trading_disabled base_min_size base_increment status_message quote_increment quote_currency max_market_funds margin_enabled display_name/];

struct( 'Toyhouse::Model::Coinbase::Product' => { map { $_ => '$' } @$ELEMENTS });

sub build($self) {
	use Data::Dumper;
	map { $_ => $self->$_() } @$ELEMENTS
}

1