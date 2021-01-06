package Toyhouse::Signer;
use MIME::Base64 qw/encode_base64 decode_base64/;
use Digest::SHA qw/hmac_sha256/;
use JSON qw/encode_json  decode_json/;
use Mojo::Base qw/-strict -signatures/;
use Class::Struct;

my $WS_SIG_PATH = '/users/self/verify';
my $WS_SIG_METHOD = 'GET';

struct('Toyhouse::Signer' => {
	signature => '$',
	key => '$',
	passphrase => '$',
	secret => '$'
});

sub generate_signature(@args) {
	return substr(encode_base64( hmac_sha256(@args) ), 0, -1); #remove newline
}

sub sign_ws_subscription($self, $subscription) {
	return encode_json($subscription) unless my $secret = $self->secret;
	
	my $body = '';
	my $signature = generate_signature(
		my $timestamp = time(),
		$WS_SIG_METHOD,
		$WS_SIG_PATH,
		$body,
		decode_base64( $secret ) );

	return encode_json({
			key			=> $self->key,
			passphrase	=> $self->passphrase,
			signature	=> $signature,			
			timestamp	=> $timestamp, 
			%{ $subscription } 
	});
}

sub sign($self, $mojo_tx_req_obj) {
	return unless my $secret = $self->secret();
	my $signature = generate_signature(
			my $timestamp = time(),
			$mojo_tx_req_obj->req->method(), 
			($mojo_tx_req_obj->req->url->query->{string} ne '') ? $mojo_tx_req_obj->req->url->path(). '?'. $mojo_tx_req_obj->req->url->query->{string} : $mojo_tx_req_obj->req->url->path(), 
			$mojo_tx_req_obj->req->body(), 
			decode_base64( $secret ) );

	$mojo_tx_req_obj->req->headers->header( 'CB-ACCESS-TIMESTAMP', $timestamp );
	$mojo_tx_req_obj->req->headers->header( 'CB-ACCESS-PASSPHRASE', $self->passphrase() );	
	$mojo_tx_req_obj->req->headers->header( 'CB-ACCESS-KEY', $self->key() );
	$mojo_tx_req_obj->req->headers->header( 'CB-ACCESS-SIGN', $signature );
}

1