package Toyhouse::Provider::Coinbase::API::Endpoint;
use strict;
use warnings;
use Toyhouse::Provider::Coinbase::API::Endpoint::Accounts;
use Toyhouse::Provider::Coinbase::Configuration::REST;
use Toyhouse::Provider::Coinbase::Request::Path;

use Class::Struct 'Toyhouse::Provider::Coinbase::API::Endpoint' => [
    this => '@', # [resource, API] # ['accounts', 'ListAccounts']
    query_params => 'Toyhouse::Provider::Generic::API::Query',
    request_path => 'Toyhouse::Provider::Coinbase::Request::Path'
];

our $BASE_URL = $Toyhouse::Provider::Coinbase::Configuration::REST::BASE_URL;
our $PATH_SEPARATOR = '/';

Readonly::Scalar my $RESOURCE => {
    accounts => {
        resource => Toyhouse::Provider::Coinbase::API::Endpoint::Accounts::resource,
        method => $Toyhouse::Provider::Coinbase::API::Endpoint::Accounts::API }
};

sub as_url {
    $_[0]->_update_path;

    my $url = ();
    if ($_[0]->this and (ref($_[0]->this) =~ /ARRAY/)) {
        return join($PATH_SEPARATOR, ($BASE_URL, $_[0]->request_path->build->as_string));
    }
    return $_[0]->this($url);
}

sub r_path {
    $_[0]->_update_path;

    return $_[0]->request_path;
};

sub _update_path {
    my $path = ();
    my $api = 'accounts';

    if ((not $_[0]->request_path) or (ref($_[0]->request_path) !~ /Path/)) {
        $path = Toyhouse::Provider::Coinbase::Request::Path->new(
                this => [$RESOURCE->{$api}->{resource}])->build;
    } else { 
        $path = $_[0]->request_path;
    }
    $_[0]->request_path($path);
}
1;