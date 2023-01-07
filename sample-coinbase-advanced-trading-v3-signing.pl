#!/usr/bin/perl
use warnings;
use strict;

use JSON;
use Data::Dumper;
use Toyhouse::Provider::Coinbase::Client;

my $json = JSON->new;
my $client = Toyhouse::Provider::Coinbase::Client->new;
my $output = $client->request(['accounts', 'ListAccounts']);

1;