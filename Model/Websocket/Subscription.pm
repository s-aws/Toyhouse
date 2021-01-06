package Toyhouse::Model::Websocket::Subscription;
use Mojo::Base qw/-strict -signatures/;
use Class::Struct('Toyhouse::Model::Websocket::Subscription' => {
	type => '$',
	channels => '@',
	product_ids => '@',
});

sub payload ($self) {
	return {
		type => $self->type, #subscribe / unsubscribe
		channels => $self->channels,
		product_ids => $self->product_ids,
	}
}

1