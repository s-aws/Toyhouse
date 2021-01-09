package Toyhouse::Coinbase::Private::Accounts;
use Readonly;
use Toyhouse::Model::Coinbase::API;
use Toyhouse::Coinbase::Request;
use Toyhouse::Model::Coinbase::Accounts;
use Mojo::Base qw/-strict -signatures/;
use JSON qw/decode_json/;
use Class::Struct ('Toyhouse::Coinbase::Private::Accounts' => {
	req => 'Toyhouse::Coinbase::Request',
	accounts => 'Toyhouse::Model::Coinbase::Accounts'
});

Readonly my $GET => 'GET';

sub build($self) {
	$self->req( Toyhouse::Coinbase::Request->new->build() ) unless $self->req();
	return $self
}

sub update_account ($self, $account_id=undef) {
	die 'account_id is required' unless $account_id; $account_id = lc $account_id;
	$self->req->api_path( Toyhouse::Model::Coinbase::API->accounts($account_id) );
	$self->req->method($GET);
	my $content = $self->req->send();

	die $content->asset->{content} unless $content->headers->header('content-length') >= 2; # {}

	return $content->asset->{content};
	$self
}

sub update_account_history ($self, $account_id=undef) {
	die 'account_id is required' unless $account_id; $account_id = lc $account_id;
	$self->req->api_path( Toyhouse::Model::Coinbase::API->accounts($account_id, 'ledger') );
	$self->req->method( $GET );
	my $content = $self->req->send();

	die $content->asset->{content} unless $content->headers->header('content-length') >= 2; # []

	return $content->asset->{content};
	$self
}

sub update_account_holds ($self, $account_id=undef) {
	die 'account_id is required' unless $account_id; $account_id = lc $account_id;
	$self->req->api_path( Toyhouse::Model::Coinbase::API->accounts($account_id, 'holds') );
	$self->req->method( $GET );
	my $content = $self->req->send();

	die $content->asset->{content} unless $content->headers->header('content-length') >= 2; # []

	return $content->asset->{content};
	$self
}


sub update_accounts ($self) { # signer => $self->signer(); init is also required before send on signed requests # ->init->send();
	$self->req->api_path( Toyhouse::Model::Coinbase::API->accounts() );
	$self->req->method( $GET );
	my $content = $self->req->send();

	die $content->asset->{content} unless $content->headers->header('content-length') >= 2; # []

	$self->accounts(Toyhouse::Model::Coinbase::Accounts->new->build(@{ decode_json( $content->asset->{content} ) }) );
	$self
}
