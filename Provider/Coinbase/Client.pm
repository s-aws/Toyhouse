package Toyhouse::Provider::Coinbase::Client;
use warnings;
use strict;

use LWP::UserAgent;
use Toyhouse::Provider::Generic::Request::Body;
use Toyhouse::Provider::Generic::Request::Method;
use Toyhouse::Provider::Coinbase::Request::Path;
use Toyhouse::Provider::Coinbase::API::Endpoint;
use Toyhouse::Provider::Coinbase::Auth;
use Toyhouse::Provider::Coinbase::Auth::Credentials;
use Toyhouse::Provider::Coinbase::Auth::Payload;
use Toyhouse::Provider::Coinbase::Timestamp;

use Class::Struct   'Toyhouse::Provider::Coinbase::Client' => {
    api_endpoint=>  '$',
    auth        =>  '$',
    body        =>  '$',
    credentials =>  '$',
    method      =>  '$',
    payload     =>  '$',
    request_path=>  '$',
    timestamp   =>  '$' };

my $USERAGENT = LWP::UserAgent->new;

sub request {
    # self, resource, api
    $_[0]->body(Toyhouse::Provider::Generic::Request::Body->new) unless 
        $_[0]->body and (ref($_[0]->body) !~ /SCALAR/);

    $_[0]->api_endpoint(Toyhouse::Provider::Coinbase::API::Endpoint->new(this => $_[0]->api_endpoint)) if
        $_[0]->api_endpoint and (ref($_[0]->api_endpoint) =~ /ARRAY/);

    $_[0]->request_path($_[0]->api_endpoint->r_path);

    $_[0]->method(Toyhouse::Provider::Generic::Request::Method->get) unless $_[0]->method;

    $_[0]->timestamp(Toyhouse::Provider::Coinbase::Timestamp->new) unless $_[0]->timestamp;

    $_[0]->credentials(Toyhouse::Provider::Coinbase::Auth::Credentials->new) unless
        $_[0]->credentials and (ref($_[0]->credentials) !~ /REF/);

    $_[0]->payload(Toyhouse::Provider::Coinbase::Auth::Payload->new(
        body        => $_[0]->body,
        method      => $_[0]->method,
        request_path=> $_[0]->request_path,
        timestamp   => $_[0]->timestamp));

    $_[0]->auth(Toyhouse::Provider::Coinbase::Auth->new(
        credentials => $_[0]->credentials->resolve,
        payload     => $_[0]->payload)) unless $_[0]->auth;

    my $headers = $_[0]->auth->generate_request_signature_headers;
    my $req = HTTP::Request->new(
            $_[0]->method => $_[0]->api_endpoint->as_url);

    $req->header(%$headers);
    return $USERAGENT->request($req);
}
1;