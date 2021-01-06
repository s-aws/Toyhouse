package Toyhouse::Coinbase::Request;
use Readonly;
use Time::HiRes qw/sleep/;
use Toyhouse::UserAgent;
use Mojo::Base qw/-strict -signatures/;
use Class::Struct ('Toyhouse::Coinbase::Request' => {
	api_path => '$',
	body => '$',
	query_parameters => '@',
	method => '$',
	ua => 'Toyhouse::UserAgent',
	signer => 'Toyhouse::Signer',
	max_pages => '$',
});

Readonly my $URL => 'https://api.pro.coinbase.com';

sub build($self) { # required for signed requests
	$self->ua( Toyhouse::UserAgent->new() ) unless $self->ua();
	$self->ua->signer( $self->signer() ) if $self->signer();
	$self;
}

sub send($self) {
	die 'method and api_path are required' unless $self->method() && $self->api_path();
	my ($r,$o);
	my $method = lc $self->method();
	my $url = join('/', $URL, $self->api_path());
	my $body = [do {$self->body()? (json => $self->body()) : ()}];
	my $query_string = scalar($self->query_parameters()) ? '?'. join('&', @{ $self->query_parameters() }) : ();
 	my $ua = $self->ua->build();
 	$self->ua->fastball('curve');
 	my $page_counter = 0; my $last_token;
 	do {
 		my $pagination = ();

 		if ($o && (my $token = $o->res->content->headers->header('cb-after'))) {
 			$pagination = ($query_string ? '&' : '?') . 'after='. $token. '&limit=100';
 			$last_token = $token
 		}

 		my $full_url = $url;
 		$full_url .= $query_string if $query_string;
 		$full_url .= $pagination if $pagination;

 		$o = $ua->$method( $full_url => @$body );

 		if ($o->res->content->headers->header('content-length') > 2) {
 			if ($r) {
	 			if ($o->res->content->asset->{content} =~ /exceeded/) { #throttled
	 				print STDERR $o->res->content->asset->{content}. " sleeping 1 second\n";
		 			sleep 1;
		 			$o->res->content->headers->header('cb-after', $last_token);
		 			$page_counter--;
	 			}
	 			else {
	 				$r->res->content->asset->{content} = substr($r->res->content->asset->{content}, 0, -1). ',['. substr($o->res->content->asset->{content}, 1) #concat the new pages to the (required) json
	 			}
 			}
 			else {
 				$r = $o;
 			}
 		}
 		else {
 			$r = $o unless $r;
 		}
 		$page_counter++;
 	}
 		while $page_counter <= ($self->max_pages() || 500) && $o->res->content->headers->header('cb-after'); 

	unless ( $r->res->error() ) { $r->res->content() }
	else { die "Did not complete as expected. ", $r->res->error->{message} } 	
}

1