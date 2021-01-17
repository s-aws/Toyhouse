package Toyhouse::Coinbase::MarketData::Products;
use Readonly;
use Toyhouse::Model::Coinbase::API;
use Toyhouse::Coinbase::Request;
use Toyhouse::Model::Coinbase::Product;
use Toyhouse::Model::Coinbase::Product::Book;
use Toyhouse::Model::Order;
use Mojo::Base qw/-strict -signatures/;
use JSON qw/decode_json/;
use Class::Struct ('Toyhouse::Coinbase::MarketData::Products' => {
	stats => '%',
	historic_rates => '%',
	order_book => '%',
	product => '%',
	product_ticker => '%',
	ticker => '%',
	trades => '%',
	req => 'Toyhouse::Coinbase::Request'
});

Readonly my $GET => 'GET';

sub build($self) {
	$self->req( Toyhouse::Coinbase::Request->new->build() ) unless $self->req();
	return $self
}

sub update_24hr_stats ($self, $product_id=undef) {
	die 'product_id required' unless $product_id; $product_id = uc $product_id;	

	$self->req->api_path( Toyhouse::Model::Coinbase::API->products($product_id, 'stats') );
	$self->req->method( $GET );
	my $content = $self->req->send();

	die $content->asset->{content} unless $content->headers->header('content-length') >= 2; # {}

	$self->stats($product_id => decode_json($content->asset->{content}));
	$self
}

sub update_historic_rates ($self, $product_id=undef, $granularity_param='granularity=60', $start=undef, $end=undef) {
	die 'product_id required' unless $product_id; $product_id = uc $product_id;	

	$self->req->api_path( Toyhouse::Model::Coinbase::API->products($product_id, 'candles') );
	$self->req->method( $GET );
	$self->req->query_parameters( [$granularity_param] );
	my $content = $self->req->send();

	die $content->asset->{content} unless $content->headers->header('content-length') >= 2; # {}

	$self->historic_rates($product_id => decode_json($content->asset->{content}));
	$self
}

sub update_ticker ($self, $product_id=undef) {
	die 'product_id required' unless $product_id; $product_id = uc $product_id;	

	$self->req->api_path( Toyhouse::Model::Coinbase::API->products($product_id, 'ticker') );
	$self->req->method( $GET );
	my $content = $self->req->send();

	die $content->asset->{content} unless $content->headers->header('content-length') >= 2; # {}

	$self->ticker($product_id => Toyhouse::Model::Order->new( %{ decode_json($content->asset->{content}) } )->build()->no_class() );
	$self
}

sub update_products ($self) {
	$self->req->api_path( Toyhouse::Model::Coinbase::API->products() );
	$self->req->method( $GET );
	my $content = $self->req->send();

	die $content->asset->{content} unless $content->headers->header('content-length') >= 2; # []

	my $product_ids = { 
		map { 
			$_->{id} => {
				Toyhouse::Model::Coinbase::Product->new(%$_)->build()
			} 
		} @{decode_json($content->asset->{content})} 
	};
	
	$self->product( $product_ids );
	return $self;
}

sub update_order_book ($self, $product_id=undef, $arg='level=1') { #update_product_order_book('BTC-USD', $arg); # $arg = 'level=1', 'level=2', 'level=3'
	die 'product_id required' unless $product_id; $product_id = uc $product_id;
#	$self->order_book($product_id) unless $self->order_book($product_id);

	$self->req->api_path( Toyhouse::Model::Coinbase::API->products($product_id, 'book') );
	$self->req->method( $GET );
	$self->req->query_parameters( [$arg] );
	my $content = $self->req->send();

	die $content->asset->{content} unless $content->headers->header('content-length') >= 2; # {}

	my $json = decode_json($content->asset->{content}) || die $content->asset->{content}; 
	
	$self->order_book( $product_id, Toyhouse::Model::Coinbase::Product::Book->new( asks => $json->{asks}, bids => $json->{bids} ) );
	return $self;
}

sub update_trades ($self, $product_id=undef) {
	die 'product_id required' unless $product_id; $product_id = uc $product_id;	

	$self->req->api_path( Toyhouse::Model::Coinbase::API->products($product_id, 'trades') );
	$self->req->method( $GET );
	my $content = $self->req->send();

	die $content->asset->{content} unless $content->headers->header('content-length') >= 2; # {}

	my $trades = [map{ Toyhouse::Model::Order->new( %$_ )->build->no_class() } @{ decode_json($content->asset->{content}) } ];#

	$self->trades($product_id => $trades);

	return $self
}

sub get_products ($self) {
	return ($self->product() || $self->update_products->product())
}

sub get_product ($self, $product_id=undef) { 
	die 'product_id required' unless $product_id; $product_id = uc $product_id;
	return ($self->product( $product_id ) || $self->update_products->product( $product_id ))
}

sub get_order_book($self, $product_id=undef, $sequence=undef, $scope=undef) { #get_product_order_book('BTC-USD'); #get_product_order_book('BTC-USD')->[0]; #get_product_order_book('BTC-USD', $latest_sequence)->asks;
	die 'product_id required' unless $product_id; $product_id = uc $product_id;
	return [sort( keys(%{ $self->order_book($product_id) }) )] unless $sequence;
	return $self->order_book($product_id)->{$sequence} unless $scope && $scope =~ /^asks|bids$/;
	return $self->order_book($product_id)->{$sequence}->$scope;
}

1