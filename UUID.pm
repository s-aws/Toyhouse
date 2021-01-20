package Toyhouse::UUID;
use Mojo::Base qw/-strict -signatures/;
use Data::UUID;
use Class::Struct ('Toyhouse::UUID' => {
	ug => 'Data::UUID',
	scope => '$',
});

sub build ($self) {
	my $scope = 'trade.epaywise.com';
	
	$self->scope( $scope ) unless $self->scope();
	$self->ug( Data::UUID->new() ) unless $self->ug();
	$self;
}

sub generate($self, $arg='default') {
	return (lc $self->ug->create_from_name_str( NameSpace_DNS, $self->scope(). $arg ) || 0);
}

1;
