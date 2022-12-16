package Toyhouse::Auth::signature;
use warnings;
use strict;

BEGIN {require Toyhouse::Core}

*encode_json 	= *Toyhouse::Core::encode_json;
*encode_base64 	= *Toyhouse::Core::encode_base64;
*decode_base64 	= *Toyhouse::Core::decode_base64;
*hmac_sha256  	= *Toyhouse::Core::hmac_sha256;

*set	=	sub { #must set env to use websocks
	my $self = shift;
	bless {$_[0] => $_[1]}, $self};

sub sign {
	encode_base64(
		hmac_sha256( @_	)
	)
}

sub signFIX {
	my $join_char = chr(1);
	return sign(join($join_char, @_))
}

sub new {

	my $self= shift;
	my $a = shift; #auth hash
	#use Data::Dumper;
	#print STDERR Dumper $a;
	# spk (secret passphrase hash) will hold all the resulting values we need to sign
	my $spk = {	secret		=> $a->{secret},
				passphrase	=> $a->{passphrase},
				key			=> $a->{key},
				ws_auth_path=> '/users/self/verify', #the path when signing for websocket
				cb_prefix	=> 'cb-access-' };

	# $l contains the headers which change depending on if this is a websocket auth or a rest auth
	my $l	= { k	=>	'key',
				s	=>	'sign',
				t	=>	'timestamp',
				p	=>	'passphrase' };

	# bless if not already. if *set was used, this exists
	if (ref($self) ne __PACKAGE__) {$self = bless {}, $self}

	#method required for the signature
	$self->{method}= shift;

	# path the request goes to
	$self->{path} 	=
		delete($self->{env}) ?

			do { #this is set for ws requests // we can do a delete check since we don't need it anymore
				$l->{s} .= 'ature'; #websocket uses 'signature' header name but rest api uses 'sign'
				$spk->{ws_auth_path}
			} :

			do { #this iswhere we finalize the http header name, we're being dirty for reusing $l
				$l 	= { # Using cp_prefix and the $l hash values.
						# example k => CB-ACCESS-KEY
					k 	=> uc $spk->{cb_prefix}.$l->{k},
					s 	=> uc $spk->{cb_prefix}.$l->{s},				
					t 	=> uc $spk->{cb_prefix}.$l->{t},				
					p 	=> uc $spk->{cb_prefix}.$l->{p},				
				};
				shift;
			};

	# the body should be in json but we're going to encode it just in case it isnt, we really shouldn't be doing this here
	$self->{body} = (defined($_[0]) && ref($_[0]) && (ref($_[0]) eq 'HASH')) ? eval{encode_json($_[0])} // $_[0] : '';#does not like undef
	$self->{timestamp} = time;
	$self->{signature} = sign($self->{timestamp}, $self->{method}, $self->{path}, $self->{body}, decode_base64($spk->{secret}));

	#we must chomp the signature or we'll have an additional space at the end.
	chomp $self->{signature}; 

	# the keys for sig_payload are the headers as they should be when sending the request
	$self->{sig_payload} = {
			$l->{k}	=> $spk->{key},
			$l->{s}	=> $self->{signature},
			$l->{t}	=> $self->{timestamp},
			$l->{p}	=> $spk->{passphrase}
	};

	return { 
		headers 	=> $self->{sig_payload}, 
		method 		=> $self->{method}, 
		path 		=> $self->{path}, 
		body 		=> $self->{body} 
	};
}

1;
