package Toyhouse::Generated::coinbase;
use warnings;
use strict;
use Readonly;
use Data::Dumper;
use Toyhouse::Client;

my Readonly $client = sub {Toyhouse::Client->new_session(@_)};

my Readonly $me = sub {
	my $iam = (split(/::/, (caller(1))[3]))[-1]; 
	$iam =~ s/set_?(.*)/$1/; 
	$iam;
};

my Readonly $set = sub {
	my $self = shift; 
		my ($r, $delete_chain_flag) = (undef, 1); 
		my ($opts, $location) = ('opts', 'location');
		my $optl = "$opts" . "_" . "$location";
		$self->{$opts} = {} unless $self->{$opts}; 
		$self->{$optl} = {} unless $self->{$optl};
		my $p = shift; #parameter

		unless ($p =~ /(api|api_action)/) {
			if ($p =~ /(body|path|query)/) {$r = $self->{$optl}; $r->{$1} = [] unless $r->{$1}}
			else {
				$r = $self->{$opts};
				#allow chaining
				undef $delete_chain_flag; $self->{set_chain} = $p;
			}
			push @{$r->{$p}}, shift
		}
		else {$self->{$p} = $_[0]}
		delete $self->{set_chain} if ($self->{set_chain} && $delete_chain_flag);
		$self;
};

my Readonly $get = sub {
	return undef unless scalar(@_) >= 2;
		my $r = shift;
		unless ($_[0] =~ /api_action|api/) {
			if ($_[0] eq 'query') {my $q = shift(@_); $r = $r->{opts}->{$q}}
			else {$r = $r->{opts}}
		}
		return $r->{$_[0]};
};

my Readonly $_opts_location = sub {
	$_[0]->{set_chain} ? $_[0]->{set_chain} : $_[1];
};

sub query {
	return undef unless ($_[0]->{api}); 
			my $p = $_opts_location->($_[0], $me->());
			$set->($_[0], $me->() => $p =>);
}

sub path {
	return undef unless ($_[0]->{api}); 
			my $p = $_opts_location->($_[0], $me->());
			$set->($_[0], $me->() => $p =>);
}

sub body {
	return undef unless ($_[0]->{api}); 
			my $p = $_opts_location->($_[0], $me->());
			$set->($_[0], $me->() => $p =>);
}

my Readonly $method = {
	cancel_all => 'DELETE',
	cancel_order => 'DELETE',
	coinbase => 'POST',
	create_conversion => 'POST',
	create_websocket => 'GET',
	crypto => 'POST',
	get_24hour_stats => 'GET',
	get_account => 'GET',
	get_account_history => 'GET',
	get_currencies => 'GET',
	get_fees => 'GET',
	get_fills => 'GET',
	get_historical_rates => 'GET',
	get_holds => 'GET',
	get_order => 'GET',
	get_product_order_book => 'GET',
	get_product_ticker => 'GET',
	get_products => 'GET',
	get_time => 'GET',
	get_trades => 'GET',
	list_accounts => 'GET',
	list_orders => 'GET',
	list_payment_method => 'GET',
	payment_method => 'POST',
	place_order => 'POST',
};

my Readonly $path = {
	cancel_all => '/orders',
	cancel_order => '/orders',
	coinbase => '/withdrawals',
	create_conversion => '/conversions',
	create_websocket => '/users/self/verify',
	crypto => '/withdrawals',
	get_24hour_stats => '/products',
	get_account => '/accounts',
	get_account_history => '/accounts',
	get_currencies => '/currencies',
	get_fees => '/fees',
	get_fills => '/fills',
	get_historical_rates => '/products',
	get_holds => '/accounts',
	get_order => '/orders',
	get_product_order_book => '/products',
	get_product_ticker => '/products',
	get_products => '/products',
	get_time => '/time',
	get_trades => '/products',
	list_accounts => '/accounts',
	list_orders => '/orders',
	list_payment_method => '/payment-methods',
	payment_method => '/withdrawals',
	place_order => '/orders',
};

my Readonly $old_parameter_name = {
	api_publicsandboxprocoinbasecom => 'api-public.sandbox.pro.coinbase.com',
	apiprocoinbasecom => 'api.pro.coinbase.com',
	coinbase_account => 'coinbase-account',
	fix_publicsandboxprocoinbasecom4198 => 'fix-public.sandbox.pro.coinbase.com:4198',
	fixprocoinbasecom4198 => 'fix.pro.coinbase.com:4198',
	payment_method => 'payment-method',
	procoinbasecom => 'pro.coinbase.com',
	publicsandboxprocoinbasecom => 'public.sandbox.pro.coinbase.com',
	tcpssl => 'tcp+ssl',
	ws_feed_publicsandboxprocoinbasecom => 'ws-feed-public.sandbox.pro.coinbase.com',
	ws_feedprocoinbasecom => 'ws-feed.pro.coinbase.com',
};

sub new {
	my $self = shift;
	bless {session => $client->(@_)}, $self;
}

sub send {
	my $self = shift;

	my $opts = $self->{opts} || undef;
	my $opts_location = $self->{opts_location} || undef;

	my $api_action = $self->{api_action};
	my $api = $self->{api};

	my $s = $self->{session};
	my $m = $method->{$api_action};
	my $p = $path->{$api_action};

	my ($body, $b);

	my $opts_key_list = [keys($opts_location)];

	if (keys(%$opts)) {
		# This sort is to make sure path is done before query (required!!)
		foreach my $q (sort(@$opts_key_list)) {

			if (($opts_location->{$q}) && (scalar(@{$opts_location->{$q}}) >= 1)) {
				my $opts_array_hash = $opts_location->{$q};

				if ($q =~ /(path|query)/) {
					$p .= '?' if ($1 eq 'query');
					my $string_maker = sub {if ($_[0] eq 'query') {return $_[2] . '=' . $_[1] . '&'} else {return '/' . $_[1]}};

					foreach my $key (@{$opts_array_hash}) {
						foreach (@{$opts->{$key}}) {
							$p .= $string_maker->(
								$1, 
								# We swap in $old_parameter_name here because we changed it earlier
								($old_parameter_name->{$_} || $_), 
								$key,);
						}
					}
				}
				elsif ($q eq 'body') {
					foreach my $key (@{$opts_array_hash}) {
						foreach (@{$opts->{$key}}) {
							$body->{$key} = $_;
						}
					}
					$b = $body
				}
			}
		}
	} #opts doesn't exist, a pitty, make sure this is a resend: m, p, are undef
	elsif (!defined($m) && !defined($p)) {
		# reusing the last request 
		$m = $self->{last_request_cache}->{method};
		$p = $self->{last_request_cache}->{path};
		$b = $self->{last_request_cache}->{body};
	}

	$self->{last_request_cache} = {method => $m, path => $p, body => $b} if keys(%$opts);
	%$opts_location = (); %$opts = ();

	if ($api eq 'ws') {
		return $Toyhouse::Client::new_websocket_session->($s, $b);
	}
	else {
		return $Toyhouse::Client::send->($s, $m, $p, $b);
	}
}

sub account_id {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub accounts {
	$set->($_[0], api => $me->());
	shift;
}

sub activate {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub amount {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub api_publicsandboxprocoinbasecom {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub apiprocoinbasecom {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub book {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub cancel_after {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub cancel_all {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub cancel_order {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub candles {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub change {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub channels {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub client {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub client_oid {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub coinbase {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub coinbase_account {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub coinbase_account_id {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub conversions {
	$set->($_[0], api => $me->());
	shift;
}

sub create_conversion {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub create_websocket {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub crypto {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub crypto_address {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub currencies {
	$set->($_[0], api => $me->());
	shift;
}

sub currency {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub date {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub deposits {
	$set->($_[0], api => $me->());
	shift;
}

sub destination_tag {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub done {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub end {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub endpoints {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub fees {
	$set->($_[0], api => $me->());
	shift;
}

sub fills {
	$set->($_[0], api => $me->());
	shift;
}

sub fix_publicsandboxprocoinbasecom4198 {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub fixprocoinbasecom4198 {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub float {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub from {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub full {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub funds {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub generalconfiguration {
	$set->($_[0], api => $me->());
	shift;
}

sub get_24hour_stats {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub get_account {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub get_account_history {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub get_currencies {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub get_fees {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub get_fills {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub get_historical_rates {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub get_holds {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub get_order {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub get_product_order_book {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub get_product_ticker {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub get_products {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub get_time {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub get_trades {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub granularity {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub heartbeat {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub holds {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub https {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub id {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub integer {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub l2update {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub ledger {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub level {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub limit {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub list_accounts {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub list_orders {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub list_payment_method {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub maker_order_id {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub market {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub match {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub matches {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub name {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub new_funds {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub new_size {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub no_destination_tag {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub old_funds {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub old_size {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub open {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub order_id {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub order_type {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub orders {
	$set->($_[0], api => $me->());
	shift;
}

sub payment_method {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub payment_method_id {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub payment_methods {
	$set->($_[0], api => $me->());
	shift;
}

sub place_order {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub post_only {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub price {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub private {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub procoinbasecom {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub product_id {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub product_ids {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub products {
	$set->($_[0], api => $me->());
	shift;
}

sub profile_id {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub publicsandboxprocoinbasecom {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub reason {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub received {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub remaining_size {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub sequence {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub set_account_id {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_activate {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_amount {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_api_publicsandboxprocoinbasecom {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_apiprocoinbasecom {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_book {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_cancel_after {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_candles {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_change {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_channels {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_client {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_client_oid {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_coinbase_account {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_coinbase_account_id {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_crypto {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_crypto_address {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_currency {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_date {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_destination_tag {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_done {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_end {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_fix_publicsandboxprocoinbasecom4198 {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_fixprocoinbasecom4198 {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_float {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_from {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_full {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_funds {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_granularity {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_heartbeat {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_holds {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_https {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_id {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_integer {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_l2update {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_ledger {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_level {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_limit {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_maker_order_id {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_market {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_match {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_matches {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_name {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_new_funds {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_new_size {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_no_destination_tag {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_old_funds {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_old_size {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_open {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_order_id {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_order_type {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_payment_method {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_payment_method_id {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_post_only {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_price {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_private {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_procoinbasecom {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_product_id {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_product_ids {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_profile_id {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_publicsandboxprocoinbasecom {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_reason {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_received {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_remaining_size {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_sequence {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_side {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_size {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_start {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_stats {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_status {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_stop {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_stop_price {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_stop_type {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_stp {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_subscribe {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_taker_order_id {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_tcpssl {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_ticker {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_time {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_time_in_force {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_timestamp {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_to {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_trade_id {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_trades {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_true {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_type {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_user_id {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_ws_feed_publicsandboxprocoinbasecom {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_ws_feedprocoinbasecom {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub set_wss {
	return undef unless ($get->($_[0] => "api")); 
	$set->($_[0], $me->() => $_[1]);
}

sub side {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub size {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub start {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub stats {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub status {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub stop {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub stop_price {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub stop_type {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub stp {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub subscribe {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub taker_order_id {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub tcpssl {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub ticker {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub time {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub time_in_force {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub timestamp {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub to {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub trade_id {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub trades {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub true {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub type {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub user_id {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub websocket_market_feed_message_structure {
	$set->($_[0], api_action => $me->());
	$_[0]->send;
}

sub withdrawals {
	$set->($_[0], api => $me->());
	shift;
}

sub ws {
	$set->($_[0], api => $me->());
	shift;
}

sub ws_feed_publicsandboxprocoinbasecom {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub ws_feedprocoinbasecom {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}

sub wss {
	return ($get->($_[0]->{$me->()}, $me->()) || undef);
}


1;
