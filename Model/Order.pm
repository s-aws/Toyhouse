package Toyhouse::Model::Order;
use Mojo::Base qw/-strict -signatures/;
use Mojo::JSON qw/encode_json/;
use Toyhouse::DataValidator;
use Toyhouse::Model::Order::Internal;
use Class::Struct('Toyhouse::Model::Order' => { map { $_ => '$' } qw(
	product_id side type time order_id price size order_type 
	funds remaining_size reason maker_order_id taker_order_id 
	taker_user_id user_id taker_profile_id profile_id taker_fee_rate
	maker_user_id maker_profile_id maker_fee_rate new_size old_size 
	new_funds old_funds stop_price id time_in_force post_only created_at
	done_at done_reason filled fill_fees filled_size executed_value
	status settled private trade_id ask bid volume client_oid)});

sub no_class($self) { #some people have # build() has become extremely popular to change the format of time so no_class was created to remove the __PACKAGE__ name from the resulting build #build->no_class().
	my $o = {}; 
	foreach my $key (keys %{ $self }) {
		$o->{ [ split(/::/, $key) ]->[-1] } = $self->{ $key } 
	}
	return $o;
}

sub to_json($self) {
	return encode_json( $self->no_class() );
}

sub build($self) {
	foreach my $key (keys %{ $self }) {
		do {delete $self->{ $key }; next} if !defined($self->{ $key }); # get rid of undefined
		Toyhouse::DataValidator->validate( 
			# Toyhouse::Model::Order::element;
			[ split(/::/, $key) ]->[-1], 
			\$self->{ $key } 
		);
	}

	return $self
}

sub change_price_by($self, $amount, $unit='$') { #change_price_by(1 => '%'); change_price_by(1 => '$'); change_price_by(-1 => '$'); change_price_by(-1 => '%')
	return if $unit && $unit !~ /^\$|\%/;
	my $price = $self->price();
	$self->price(sum($price, (($unit eq '%') ? product($price, to_percent($amount)) : $amount) ));

	return $self
}

sub change_size_by($self, $amount, $unit=undef) { #change_size_by(1 => '%'); change_size_by(1); change_price_by(-1); change_price_by(-1 => '%')
	return if $unit && $unit ne '%';
	my $size = $self->size();
	$self->size(sum($size, ($unit ? product($size, to_percent($amount)) : $amount) ));

	return $self
}

1;
