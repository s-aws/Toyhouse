package Toyhouse::Model::Coinbase::Product::Book;
use Readonly;
use Mojo::Base qw/-strict -signatures/;
use Class::Struct;

Readonly my $ELEMENTS => [qw/bids asks/];

struct( 'Toyhouse::Model::Coinbase::Product::Book' => { map { $_ => '@' } @$ELEMENTS });

#sub build($self) {	map { $_ => $self->$_() } @$ELEMENTS }

1