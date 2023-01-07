#!/usr/bin/perl
use warnings;
use strict;

use Data::Dumper;
use Toyhouse::Provider::Coinbase::Client;
use Toyhouse::Provider::Coinbase::API::Endpoint::Products::ListProducts;

my $client = Toyhouse::Provider::Coinbase::Client->new(
    api_endpoint => Toyhouse::Provider::Coinbase::API::Endpoint::Products::ListProducts->api_endpoint);

my $output = $client->request;

print Dumper($output);

1;