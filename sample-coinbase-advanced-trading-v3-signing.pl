#!/usr/bin/perl

use warnings;
use strict;

use Data::Dumper;

use Toyhouse::Provider::Generic::Request::Body;
use Toyhouse::Provider::Generic::Request::Method;
use Toyhouse::Provider::Coinbase::Request::Path;
use Toyhouse::Provider::Coinbase::API::Endpoint;
use Toyhouse::Provider::Coinbase::Auth;
use Toyhouse::Provider::Coinbase::Auth::Credentials;
use Toyhouse::Provider::Coinbase::Auth::Payload;
use Toyhouse::Provider::Coinbase::Timestamp;

my $body = Toyhouse::Provider::Generic::Request::Body->new;
my $method = Toyhouse::Provider::Generic::Request::Method->get;
#my $request_path = Toyhouse::Provider::Coinbase::Request::Path->new(this => );
my $api_endpoint = Toyhouse::Provider::Coinbase::API::Endpoint->new(this => [accounts => 'ListAccounts']);
my $timestamp = Toyhouse::Provider::Coinbase::Timestamp->new();

my $credentials = Toyhouse::Provider::Coinbase::Auth::Credentials->new();
my $payload = Toyhouse::Provider::Coinbase::Auth::Payload->new(
    body => $body,
    method => $method,
    request_path => $api_endpoint->r_path,
    timestamp => $timestamp);

my $auth = Toyhouse::Provider::Coinbase::Auth->new(
    credentials => $credentials,
    payload => $payload);

use LWP::UserAgent;
my $ua = LWP::UserAgent->new;

my $req = HTTP::Request->new(
    $method => $api_endpoint->as_url);

my $headers = $auth->generate_request_signature_headers;

$headers->{accept} = "application/json"; 
$req->header(%$headers);

my $res = $ua->request($req);

use JSON;
my $json = JSON->new;
print Dumper($res);
print Dumper($res->content);
print Dumper($json->decode($res->content));
1;