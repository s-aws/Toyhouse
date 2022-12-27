package Toyhouse::Provider::Generic::Request::Method;
use strict;
use warnings;
use Class::Struct 'Toyhouse::Provider::Generic::Request::Method' => [
    this => '$'];

sub delete { $_[0]->this('DELETE') }
sub get { $_[0]->this('GET') }
sub head { $_[0]->this('HEAD') }
sub match { $_[0]->this('MATCH') }
sub post { $_[0]->this('POST') }
sub put { $_[0]->this('PUT') }

sub as_dict { { method => $_[0]->this } }
sub as_string { $_[0]->this }
1;