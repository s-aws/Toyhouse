package Toyhouse::Model::Coinbase::API;
use Readonly;
use Mojo::Base qw/-strict -signatures/;
use Class::Struct ('Toyhouse::Model::Coinbase::API' => {});

sub api($api, @arg) {
	unshift @arg, $api;
	return join('/', @arg)
}

sub accounts	($self, @arg)	{	return api(accounts		=> @arg	)}
sub currencies	($self, @arg)	{	return api(currencies	=> @arg	)}
sub deposits	($self, @arg)	{	return api(transfers	=> @arg )}
sub fills		($self, @arg)	{	return api(fills		=> @arg	)}
sub limits		($self, @arg)	{	return api(users		=> @arg	)}
sub orders		($self, @arg)	{	return api(orders		=> @arg	)}
sub products	($self, @arg)	{	return api(products		=> @arg	)}
sub time		($self, @arg)	{	return api(time			=> @arg	)}

1
