package Toyhouse::Websocket_message_handler;
use warnings;
use strict;
use Readonly;
use Data::Dumper;
use Toyhouse::Logging;
use Date::Parse;
use Time::HiRes qw/usleep/;

my $LOGGER = Toyhouse::Logging->new();
my Readonly $MAIN = 0;

$Data::Dumper::Sortkeys = 1;
BEGIN {require Toyhouse::Core; require AnyEvent}


sub balance {
	CORE::state $hash = undef;
	if ($_[0]) { $hash = shift; return 1}	
}

sub historic_rates {
	CORE::state $hash = {};
	if ($_[0] && $_[1] && (ref($_[1]) =~ /ARRAY/)) { 
		$hash->{shift} = shift;
		return 1
	}
	elsif ($_[0] && $hash->{$_[0]}) { 
		return $hash->{shift}
	}
}

sub received_book { # after changes are made, pass the hash back to save it for later
	CORE::state $received = undef;
	if ($_[0]) { $received = shift; return 1}
	else { return $received}
}

sub product_info {
	CORE::state $hash = undef;
	if ($_[0]) { $hash = shift; return 1}
	$hash
}

sub coinbase_client {
	CORE::state $array = undef;
	if ($_[0]) { push @{$array}, shift; return 1}
	return $array
}

sub cc_get_products {
	my ($client, $response) = (coinbase_client(), undef);

	$client->[$MAIN]->products();

	$response = $client->[$MAIN]->get_products();
	return $response;
}

sub cc_get_fees {
	my ($client, $response) = (coinbase_client(), undef);

	$client->[$MAIN]->fees();

	$response = $client->[$MAIN]->get_fees();
	return $response;
}

sub cc_list_accounts {
	my ($client, $response) = (coinbase_client(), undef);

	$client->[$MAIN]->accounts();

	$response = $client->[$MAIN]->list_accounts();
	return $response;
}

sub cc_list_orders {
	my ($client, $response) = (coinbase_client(), undef);

	$client->[$MAIN]->orders();

	$response = $client->[$MAIN]->list_orders();
	return $response;
}

sub cc_get_historic_rates {
	my ($product_id, $granularity, $client, $response) = (shift, shift, coinbase_client(), undef);

	$client->[$MAIN]->products()
		->set_product_id($product_id)->path()
		->set_candles('candles')->path()
		->set_granularity($granularity)->query();

	$response = $client->[$MAIN]->get_historical_rates();
	return $response;
}

sub cc_cancel_orders { #not tested
	my ($o, $client) = (shift, coinbase_client());
	$client->[$MAIN]->orders
		->set_product_id($o->{product_id})->query();

	my $response = $client->[$MAIN]->cancel_all();
#	print STDERR Dumper $response
}

sub cc_place_order {
	## cc_place_order( set => [cancel_after => hour])
	CORE::state $cancel_after = 'hour';
	CORE::state $good_til = 'GTT';
	CORE::state $post_only = undef;

	my $return = undef;

	if (!(scalar(@_) % 2) && defined({@_}->{set})) {
		$cancel_after = ({@_}->{set}->[0] eq 'cancel_after') ? {@_}->{set}->[1] : undef;

		if (defined($cancel_after)) {
			$good_til = 'GTT';
		}
		else {
			$good_til = 'GTC';
			undef $cancel_after;
		}

		$return = 1;

	}
	else {
		my ($o, $client) = (shift, coinbase_client());
		error $LOGGER "cc_place_order($o->{product_id}, $o->{side}, $o->{size}, $o->{price})";

		price_beautifier($o);
		size_beautifier($o); # todo, return {}->{message} = "size too small, did not place order"

		$client->[$MAIN]->orders
			->set_product_id($o->{product_id})->body()
			->set_size($o->{size})->body()
			->set_side($o->{side})->body()
			->set_price($o->{price})->body()
			->set_post_only($post_only)->body();

		$client->[$MAIN]->set_time_in_force($good_til)->body();

		if (defined($cancel_after)) {
			$client->[$MAIN]->set_cancel_after($cancel_after)->body()
		}

		if ($return = $client->[$MAIN]->place_order()) {

#			error $LOGGER "\tresponse: size: $return->{size} price: $return->{price}" if (ref($return) eq 'HASH') && $return->{size};
			if (defined($cancel_after)) {
				error $LOGGER "\tcc_placer_order: $good_til: $cancel_after";
				cc_place_order(set => [cancel_after => $cancel_after]);
			}
			else {
				error $LOGGER "\tcc_placer_order: $good_til";
			}

			#  We need some logic for failed orders, returning the order to be reattempted might not be the best
			#
			error $LOGGER "\tcc_placer_order: post_only" if defined($post_only);
		}
	}

	return $return;
}

sub get_historic_rates {
	my $product_id = shift;
	my $historic_rates_array = historic_rates($product_id);
	return $historic_rates_array
}

sub get_fees_rate {
	my $fee_hash = cc_get_fees();
	return [$fee_hash->{taker_fee_rate}, $fee_hash->{maker_fee_rate}];
}

sub put_historic_rate { 
	sub clean_time_for_bucket {
		my $time = shift;
		$time = str2time($time);
		$time *= 0.1;
		$time = int($time);
		$time *= 10;
		return $time;
	}

	sub create_rate_bucket_element {
		my $array_ref = shift;
		my ($time, $price, $size, $product_id) = (shift, shift, shift, shift);
		unshift @{$array_ref}, [$time, $price, $price, $price, $price, $size];
	}

	CORE::state $historic_rates_array = {};# get_historic_rates();
	my ($time, $low, $high, $open, $close, $volume, $o) = (0 .. 5, shift);

	if ((ref($o) =~ /HASH/) && $o->{time} && $o->{price} && $o->{size} && $o->{product_id}) {
		my ($otime, $price, $size, $product_id) = (clean_time_for_bucket($o->{time}), $o->{price}, $o->{size}, $o->{product_id});

		if ($historic_rates_array->{$product_id}) {
			for (my $i = 0; $i < scalar(@{$historic_rates_array->{$product_id}}); $i++) {
				if (@{$historic_rates_array->{$product_id}[$i]}[$time] == $otime) {
					if (@{$historic_rates_array->{$product_id}[$i]}[$low] > $price) { @{$historic_rates_array->{$product_id}[$i]}[$low] = $price }
					elsif (@{$historic_rates_array->{$product_id}[$i]}[$high] < $price) { @{$historic_rates_array->{$product_id}[$i]}[$high] = $price }
					@{$historic_rates_array->{$product_id}[$i]}[$volume] += $size;
					error $LOGGER "\t put_historic_rate: added to: $product_id:$otime";
					last;
				}
				elsif (@{$historic_rates_array->{$product_id}[$i]}[$time] < $time) {
					create_rate_bucket_element($historic_rates_array->{$product_id}, $otime, $price, $size, $product_id);
					error $LOGGER "\t put_historic_rate: created at: $product_id:$otime";
					last;
				}
			}
		}
		else { #may consolidate this later with the above
			$historic_rates_array->{$product_id} = [];
			create_rate_bucket_element($historic_rates_array->{$product_id}, $otime, $price, $size, $product_id);
			error $LOGGER "\tput_historic_rate: creating new for: $product_id @ $otime";
		}
	}
}

sub get_order {
	sub book {
		CORE::state $hash = { };
		return $hash
	}

	sub counter {
		CORE::state $hash = { };
		return $hash
	}

	sub hash {
		CORE::state $hash = { };
		return $hash
	}

	if ($_[0] eq 'hash') {return hash()}
	elsif ($_[0] eq 'book') {return book()}
	elsif ($_[0] eq 'counter') {return counter()}
}

sub get_price_from_order_hash {
	error $LOGGER "get_price_from_order_hash()";
	my ($side, $product_id, $price, $number) = (@_);
	my $order_hash = get_order('hash');
	my $result = undef;

	if ( defined($order_hash->{$product_id}->{$side})) {
		my $prices = [keys($order_hash->{$product_id}->{$side})];
		my $sorted_keys = ($side eq 'buy') ? [sort {$b <=> $a} @$prices] : [sort {$a <=> $b} @$prices];
		$result = @$sorted_keys[$number] || 0;
		error $LOGGER "\tget_price_from_order_hash: $result";
	}

	return $result
}

sub get_difference_between_price_and_last_match {
	error $LOGGER "get_difference_between_price_and_last_match()";
	my ($difference, $last_match_price) = (undef, undef);
	my $o = shift;
	my ($side, $price, $product_id, $most_recent) = ($o->{side}, $o->{price}, $o->{product_id}, 0);

	$last_match_price = get_price_from_order_hash($side, $product_id, $price, $most_recent) || $price;
	$difference = abs($last_match_price - $price) / $last_match_price; #print STDERR "$difference ";
	error $LOGGER "\tget_difference_between_price_and_last_match: $difference" if defined($difference);

	return $difference || undef;
	
}

sub get_bid {
	error $LOGGER "get_bid()";
	my ($side, $product_id, $price, $number) = (buy => @_);
	my $bid = get_price_from_order_hash($side, $product_id, $price, $number);
	error $LOGGER "\tget_bid: $bid";
	return $bid
}

sub get_quote {
	error $LOGGER "get_quote()";
	my ($side, $product_id, $price, $number) = (sell => @_);
	my $quote = get_price_from_order_hash($side, $product_id, $price, $number);
	error $LOGGER "\tget_quote: $quote";	
	return $quote
}

sub record_metric {
	my $o = shift;
	return undef unless defined($o->{product_id});
	my $order_hash = get_order('counter');
	my $time = time();	
	$order_hash->{store_order}->{counters}->{$o->{product_id}}->{$o->{type}}->{$o->{side}}->{stamp_log}->{$time} += 1;
	return $order_hash->{store_order}->{counters}->{$o->{product_id}}->{$o->{type}}->{$o->{side}}->{stamp_log}->{$time};
}

sub simple_counter {
	CORE::state $self_counter = {};
	$self_counter->{$_[0]}++;
	return $self_counter->{$_[0]}
}

sub remove_excess_zeros_from_price {
	my $o = shift;
	$o->{price} += 0;
}

sub get_product_nfo {
	error $LOGGER "get_product_nfo()";
	my $o = pop(@_);
	my $product_id = ref($o) ? $o->{product_id} : $o;
	CORE::state Readonly $product_nfo = product_info();
	CORE::state Readonly $definition = {
		# size_min => "base_min_size",
		size_increment => "base_increment",
		price_increment => "quote_increment"
	};

	my $return = [];
	foreach my $arg (@_) {
		if ($definition->{$arg}) {
			my $value = sprintf('%.10f', $product_nfo->{$product_id}->{$definition->{$arg}});
			$value =~ s/(0+)$//;
			error $LOGGER "\tget_product_nfo: $definition->{$arg}: ", $value;
			push @{$return}, $value;
		}
	}
	return @{$return};
}

sub beautifier { #should the beautifier be responsible for fees 
	# make price or size pretty (again|for the first time)
	error $LOGGER "beautifier()";	
	my $o = pop;
	my $arg = shift;
	my $ugly_too_small = 2;
	my $inc = 0;
	my $min = -1;
	my $config; 
	if ($arg eq 'price') { 
		$config = {
			increment 	=> [get_product_nfo(price_increment => $o)],
			ugly		=>	 \$o->{price}
		}
	}
	else {
		$config = {
			increment 	=> [get_product_nfo(size_increment => size_min => $o)],
			ugly		=> \$o->{size}
		};
#		return undef if (length($config->{increment}->[$inc]) < $ugly_too_small);
	}

	return $o unless defined($config);

	error $LOGGER "\tbeautifier: $arg: ${$config->{ugly}}";
	my $minimum = $config->{increment}->[$min]; 
	my $increment = $config->{increment}->[$inc];
#	my ($i, $f) = split(/\./, $config->{increment}->[$inc]);
#	my $length = length($f);
	my $almost_clean = ${$config->{ugly}} / $minimum;#sprintf('%.'. ($length || 0) .'f', ${$config->{ugly}});
	my ($clean, $left_over) = split(/\./, $almost_clean);

	${$config->{ugly}} = $clean * $minimum;

	# check the too_small_bank to see if there is anything we can withdraw
	if ($left_over) {
		$left_over = ("0." . $left_over) * $minimum;

		my $withdraw_request_amount = $minimum - $left_over;
		if ((( $o->{side} ne 'buy') && ($arg ne 'transform')) && 
			(my $withdraw_amount = too_small_bank(withdraw => $o->{product_id}, $arg, $withdraw_request_amount))) {
			
			# YAY, we got something! increasing...
			${$config->{ugly}} += $minimum;
			error $LOGGER "\tbeautifier: we withdrew: $withdraw_amount from the too_small_bank";
		}
		else { 

			#nothing to withdraw, let's deposit our too_small_value
			my $balance = too_small_bank(deposit => $o->{product_id}, $arg, $left_over);
			error $LOGGER "\tbeautifier: we deposited: $left_over into the too_small_bank:(balance: $balance)";		
		}
	}

	if (${$config->{ugly}} < $minimum) { #should happen less now (or not at all)
		error $LOGGER "\tbeautifier: too small, using minimum: $minimum";		
		${$config->{ugly}} = $minimum;
#		error $LOGGER "\tsize: $o->{size}";
	}
	error $LOGGER "\tbeautifier: new: $arg: ${$config->{ugly}}";

	#print STDERR "${$config->{ugly}} $minimum " ;
	return $o;
}

sub price_beautifier {
	my $o = shift;
	$o = beautifier(price => $o);
	return $o;
}

sub size_beautifier { #we should be able to disable correcting with a minimum
	my $o = shift;
	$o = beautifier(size => $o);
	return $o;
}


sub copy_order { #there is a better way to do this
	my $o = shift;
	my $new_o = {
		price => "$o->{price}",		
		side => "$o->{side}",
		product_id => "$o->{product_id}"};
	$new_o->{size} = get_size($o);
	return $new_o;
}

sub validate_price_move_amount {
	# quote_increment is the minimum move amount
	# calculate the movement amount. If less than minimum, return minimum
	my $o = shift;
	my $prospective_amount = shift;
	my ($min_move_amount) = get_product_nfo(price_increment => $o);
	my $prospective_move_amount = $o->{price} * $prospective_amount;

	return ($prospective_move_amount >= $min_move_amount) ? $prospective_move_amount : $min_move_amount;
}

sub order_instructor { # arg4 is a not_safe flag)
	my ($o, $command, $amount, $not_safe) = @_;
	CORE::state $fees; $fees = get_fees_rate() unless $fees; # 0 is taker, 1 is maker
	my $move_amount = 0;

	my $current_value_of_order = undef;

 	if ((($o->{side} eq 'sell') && ($command eq 'transform')) || (($o->{side} eq 'buy') && ($command ne 'transform'))) {
 		$current_value_of_order = get_order_quote_value($o);
	} # new size modification

	error $LOGGER "order_instructor()";
	error $LOGGER "\torder_instructor: command: $command($amount) price: $o->{price} side: $o->{side}";

	if ($amount != 0) {
		$move_amount = ($not_safe && ($amount < 0)) ? (validate_price_move_amount($o, $amount) * -1) : validate_price_move_amount($o, $amount);
	}

	($command eq 'transform') ? ($o->{side} eq 'buy') ?	#flip the script, make buys sells 							# and sells buys
		do{ $o->{side} = 'sell'; $o->{price} += $move_amount } : do{ $o->{side} = 'buy';	$o->{price} -= $move_amount }

								# normal shift, just move the order 	# in the correct direction
		: ($o->{side} eq 'buy') ? do { $o->{price} -= $move_amount } : do { $o->{price} += $move_amount };

	# new size modification
	if ($current_value_of_order) {
		if ($command eq 'transform') {
			$current_value_of_order *= (1 - @$fees[0]);  #taker
		}
		$o->{size} = get_size_from_order_quote_value($o, $current_value_of_order)
	} 

	error $LOGGER "\torder_instructor: price: $o->{price} size: $o->{size} side: $o->{side} move_amount: $move_amount";
	return $move_amount, $o;
}

sub shift_order { #fixed match issue, changed back to shifting $o; will fail if change size goes to 0, todo: fix
	#error $LOGGER "shifting";
	my ($o, $move_amount) = (shift, shift);
	my $default_move = 0.02 / 24;

	$o = order_instructor($o, 'shift' => $move_amount, 'not_safe');
	return $o;
}

sub transform_order {
	#error $LOGGER "transforming";
	my ($o, $move_amount) = (shift, shift);
	my $default_move = 0.011;	

	$o = order_instructor($o, 'transform' => ($move_amount <= $default_move) ? $default_move : $move_amount);
	return $o;
}

sub process {
	my ($process_type, $o) = @_;

	if ($process_type eq 'price') {
		my $new_price = remove_excess_zeros_from_price($o);
		return $new_price
	}
	elsif ({@_}->{open}) {

	}
}

sub get_size {
	my $work = shift;
	my $size = ($work->{size} || $work->{remaining_size}) || ($work->{new_size} ? ($work->{new_size} - $work->{old_size}) : 0);
	return $size;
}

sub get_order_id {
	my $work = shift;
	my $order_id = ($work->{order_id} || $work->{id} || $work->{maker_order_id});
	return $order_id;
}

sub get_order_quote_value {
	my $o = shift;
	my $value = $o->{price} * get_size($o);
	return $value;
}

sub get_size_from_order_quote_value {
	my $o = shift;
	my $value = shift;
	my $size = $value / $o->{price};
	return $size;
}

sub too_small_bank { #this bank is too small, needs to be bigger
	#store all your too small values here so we don't lose them

	CORE::state $size = {};
	CORE::state $price = {};
	my ($command, $product_id, $type, $amount, $response) = (shift, shift, shift, shift, undef);

	if ($command eq 'deposit') {
		if ($type eq 'size') {
			$size->{$product_id} += $amount;
			$response = $size->{$product_id};
		}
		elsif ($type = 'price') {
			$price->{$product_id} += $amount;
			$response = $price->{$product_id};
		}
	}
	elsif ($command eq 'withdraw') {
		if (($type eq 'size') && $size->{$product_id}) {
			if (($size->{$product_id} - $amount) >= 0) {
				$size->{$product_id} -= $amount;
			}
			else {
				$amount = undef;
			}
		}
		elsif (($type eq 'price') && $price->{$product_id}) {
			if (($price->{$product_id} - $amount) >= 0) {
				$price->{$product_id} -= $amount;
			}
			else {
				$amount = undef;
			}
		}
		else {
			$amount = undef;			
		}
		$response = $amount;
	}
	$response;
}

sub order_book_worker {
	my ($command, $work) = @_;
	my ($order_book, $order_id, $results) = (get_order('book'), 
												get_order_id($work), 
												undef);

#	print STDERR $command, ':';

	if ({@_}->{exists}) {
		if ($order_book->{$order_id}) {
			$results = 1
		}
	}
	elsif ({@_}->{get_order}) {
		$results = $order_book->{$order_id} ? $order_book->{$order_id} : -1;
	}
	elsif ({@_}->{taker_exists}) {
		# we need to use taker instead of maker
		$order_id = $work->{taker_order_id};
		if ($order_book->{$order_id}) {
			$results = 1
		}
	}
	elsif ({@_}->{open}) {
		$order_book->{$order_id} = $work;
		$results = 1
	}
	elsif ({@_}->{done}) {
		#if (($work->{reason} eq 'canceled') && (order_book_worker(has_match => $work))) {
		#	# if there was a  match for the order in the order book, keep the order
		#	$order_book->{$order_id} = $work # right now we don't have the memory to keep all orders, 
		#
		#}
		#else {
			# other wise delete the original order
			unless ($work->{user_id}) { # keeping my own orders
				$results = 1 if delete($order_book->{$order_id}) 
			}
		#}
	}
	elsif ({@_}->{change}) {
		$order_book->{$order_id}->{size} = $work->{new_size};
		$results = order_book_worker(_add_change => $work)
	}
	elsif ({@_}->{_add_change}) {
		if (push(@{$order_book->{$order_id}->{change}}, $work)) {
			$results = 1
		}
	}
	elsif ({@_}->{add_match}) {
		if (push(@{$order_book->{match}->{$order_id}}, $work)) {
			$results = 1
		}
	}	
	elsif ({@_}->{decrease_order_size}) {
		$order_book->{$order_id}->{size} -= $work->{size};
		$results = 1
	}
	elsif ({@_}->{has_match}) {
		if ($order_book->{match}->{$order_id}) {
			$results = $order_book->{match}->{$order_id}
		}
	}

#	print STDERR $results . " " if defined($results);

	return $results
}

sub add_to_order_book {
	my $o = shift;
	my $me = $o->{type};
	order_book_worker($me => $o);
}

sub is_in_order_book {
	my $me = 'exists';
	order_book_worker($me => (my $o = shift));
}

sub is_taker_in_order_book {
	my $me = 'taker_exists';
	order_book_worker($me => (my $o = shift));
}

sub has_match_in_order_book {
	my $me = 'has_match';
	order_book_worker($me => (my $o = shift));
}

sub add_match_to_order_book {
	my $me = 'add_match';	
	order_book_worker($me => (my $o = shift));
}

sub decrease_order_size_in_order_book {
	my $me = 'decrease_order_size';
	order_book_worker($me => (my $o = shift));
}

sub get_current_open_order_from_order_book {
	my $me = 'get_order';
	order_book_worker($me => (my $o = shift));
}

sub order_hash_worker {
	my ($command, $work) = @_;
	my ($order_hash, $size) = (get_order('hash'), 
								get_size($work));

	my $response = undef;

	if ({@_}->{decrease_by}) {
		$order_hash->{$work->{product_id}}->{$work->{side}}->{$work->{price}} -= $size;
		$response = order_hash_worker(clean_up => $work);
	}
	elsif ({@_}->{increase_by}) {
		$order_hash->{$work->{product_id}}->{$work->{side}}->{$work->{price}} += $size;
	}
	elsif ({@_}->{clean_up}) {

		# need to find the proper negligible margin  to delete from hash
		if ($order_hash->{$work->{product_id}}->{$work->{side}}->{$work->{price}} <= 1.0e-12) {
			$response = delete($order_hash->{$work->{product_id}}->{$work->{side}}->{$work->{price}});
		}
	}

	$response 
}

sub decrease_quantity_at_price {
	# don't do filled orders because there is no size
	order_hash_worker(decrease_by => (my $o = shift)) unless $_[0]->{reason} && ($_[0]->{reason} eq 'filled');
}

sub increase_quantity_at_price {
	order_hash_worker(increase_by => (my $o = shift));
}

sub is_order_canceled {
	if (my $o = shift) {
		if ($o->{reason} eq 'canceled') {return 1}
		elsif ($o->{reason} eq 'filled') {return undef}
	}
	return -1 # we're ignoring this for now
}

sub direction_to_move {
	error $LOGGER "direction_to_move()";
	my ($last_match_percent, $min, $max) = @_;
	my $half_min = ($min * 0.5);
	my $quarter_min = $half_min * 0.5;
	my ($direction, $increase, $decrease, $no_change) = (undef, 1, -1, 0);

	if ($last_match_percent <= $min) {
		cc_place_order(set => [cancel_after => 'hour']);
		if ($last_match_percent <= $half_min) {
			cc_place_order(set => [cancel_after => 'min'])
		}
#		else {
#			cc_place_order(set => [cancel_after => 'hour'])
#		}
		$direction = $increase;
	}
	elsif ($last_match_percent >= ($min * 10)) { # >= $min / no rest for the elderly
		cc_place_order(set => [cancel_after => 'hour']);
		$direction = $decrease;
	}
	else {
		cc_place_order(set => [cancel_after => 'hour']);		
		$direction = $no_change;
	}

	if (defined($direction)) {
		error $LOGGER "\tdirection_to_move: direction: $direction";
	} 
	else {
		error $LOGGER "\tdirection_to_move: ERROR: unable to define direction";
		$direction = $no_change;
	}

	return $direction
}

sub calculate_move_percent {
	my ($last_match_percent, $default_min) = (get_difference_between_price_and_last_match(my $o = shift), 0.01);
	error $LOGGER "calculate_move_percent()";
	my ($minutes_in_an_hour, $hours_in_a_day, $default_max, $move) = (60, 24, ($default_min * 5), undef);
	my $default_move = $default_min / ($minutes_in_an_hour * $hours_in_a_day);

	unless (defined($last_match_percent)) {
		$move = $default_move;
	}
	else {
		$move = $default_move * direction_to_move($last_match_percent, $default_min, $default_max);
	}
	
	error $LOGGER "\tcalculate_move_percent: move: $move";
	return $move
}

sub change_canceled_order_type_to_filled {
	my $o = shift;
	$o->{reason} = 'filled';
	$o->{remaining_size} = 0;
	return 1;
}

sub change_filled_order_type_to_canceled {
	my $o = shift;
	$o->{reason} = 'canceled';
	return 1;
}


sub reverse_order_side {
	my $o = shift;
	$o->{side} = 'buy' ? 'sell' : 'buy';
	return 1;
}

sub split_done_order {
	my ($o, $open_order, $original_order_size, $order_list) = (shift, shift, shift, []);

	if ($o->{remaining_size} > 0) {

		# Step 1) Create the unfilled order portion
		push @$order_list, copy_order($o);
		@{$order_list}[-1]->{size} = $o->{remaining_size};
		change_filled_order_type_to_canceled(@{$order_list}[-1]);

		# Step 2) Create the filled order portion
		if ($o->{remaining_size} < $original_order_size) {
			push @$order_list, copy_order($o);
			@{$order_list}[-1]->{size} = $original_order_size - $o->{remaining_size};
			change_canceled_order_type_to_filled(@{$order_list}[-1]);
		}
	}
	elsif ($o->{remaining_size} == 0) {
		unless ($original_order_size == 0) { #original_order_size should only be 0 if change size to 0?
			push @$order_list, copy_order($o);
			@{$order_list}[-1]->{size} = $original_order_size;
			change_canceled_order_type_to_filled(@{$order_list}[-1]);
		}
	}
	else {
		die "Should never make it here, negative remaining_size ", __LINE__
	}

	return $order_list;
}

sub move_my_order {
	my $response; 
	CORE::state $session_id = 0;
	CORE::state $transfer_counter = 0;
	$session_id++;
	my $order = shift;
	error $LOGGER "BEGIN SESSION RECORDING #$session_id ", "*"x20;

	error $LOGGER "move_my_order(", get_order_id($order), ")";

	my ($shift_type, $transform_type, $order_list) = ('canceled', 'filled', []);
	my ($move_amount, $result, $flag) = (0, undef, {$shift_type => 'S', $transform_type => 'T'});
	my $open_order = get_current_open_order_from_order_book($order); my $open_order_size = get_size($open_order);


	if (has_match_in_order_book($order)) {
		$order_list = split_done_order($order, $open_order, $open_order_size);
	}
	else { #remaining_size is unchanged
		$order->{size} = $open_order_size;
		push @{$order_list}, $order;
	}


	foreach my $o (@$order_list) {
		my $reason = $o->{reason};
		my $original_order_price = $o->{price};
#		my $o = copy_order($_o);

		$move_amount = calculate_move_percent($o);

		my $prepared_order_for_placement = ($reason eq $shift_type) ? shift_order($o, $move_amount) : transform_order($o, $move_amount);

		$result = cc_place_order($prepared_order_for_placement);

		if ($result->{message}) { 
			error $LOGGER "\tmove_my_order: ERROR: unhandled message $result->{message} ";
			print STDERR Dumper $order, $o, $prepared_order_for_placement;

			if ($result->{message} =~ /insufficient funds/) { # we should not be retrying post orders (by default)
				#do nothing
			}
		} 
		elsif (defined($result->{price})) {
			error $LOGGER "\tmove_my_order: $original_order_price => $result->{price} ", get_order_id($result);
			if ($reason eq $transform_type) { 		#cancel all orders after every 5 fills (testing)
				$transfer_counter++;
				if (!($transfer_counter % 1000)) {
					error $LOGGER "\tmove_my_order: $transfer_counter - cc_cancel_orders($result->{product_id})";
					cc_cancel_orders($result);
				}
			}
		}
		else {
			error $LOGGER "\tmove_my_order: ERROR: didn't received what I expected line:", __LINE__, " :("; 
			print STDERR Dumper $result;
		}
	}

	error $LOGGER "ENDING SESSION RECORDING #$session_id ", "*"x20;
	return $response;
}

sub process_order {
	use Data::Dumper;
	my $o = shift;
	my $command;
	if ((ref($o) =~ /HASH/) && defined($o->{type})) {
		$command = {$o->{type} => $o};
	}
	else {
		print STDERR Dumper $o
	}
	my $response = 1;

	if (type_open($command) || (
		(type_change($command) || type_done($command) || type_match($command)) &&
		is_in_order_book($o))) {

		type_open($command) ? increase_quantity_at_price($o) : decrease_quantity_at_price($o);

		add_to_order_book($o) if type_open($command) || type_change($command);

		if (type_match($command)) {
			if ($o->{user_id}) {
				add_match_to_order_book($o)
			}

			#record match metrics
			put_historic_rate($o);
		}

		elsif (type_done($command)) { #can't be match AND done
			$response = move_my_order($o) if $o->{user_id};
			add_to_order_book($o) unless !defined($response) || (ref($response) =~ /ARRAY/);
		}
	}

	$response;
}

sub store_order {
	my $metric = record_metric(my $o = shift);
	my $response; 

	simple_counter(my $me = 'store_order');	
	if ((type_received($o) && type(user_id => $o)) || !type_received($o)) {
		$response = process_order($o) if !type_received($o);
	}
	return $response;#, $metric;
}

sub type {
	return defined($_[1]->{$_[0]}) ? 1 : undef;
}

sub type_open {
	return type(open => $_[0]) ? 1 : undef;
}

sub type_received {
	return type(received => $_[0]) ? 1 : undef;
}

sub type_done {
	return type(done => $_[0]) ? 1 : undef;
}

sub type_match {
	return type(match => $_[0]) ? 1 : undef;
}

sub type_change {
	return type(change => $_[0]) ? 1 : undef;
}

sub do_nothing {
	my $order = shift;
}


sub parse_product_info {
	my $self = shift;
	my $product_info = shift;
	my $final_home = {};
	foreach my $product (@{$product_info}) {
		$product->{base_increment} = sprintf('%.10f', $product->{base_increment});
#		$product->{base_min_size} = sprintf('%.10f', $product->{base_min_size});
#		$product->{base_max_size} = sprintf('%.10f', $product->{base_max_size});		
		$product->{quote_increment} = sprintf('%.10f', $product->{quote_increment});		
		$final_home->{delete($product->{id})} = $product
	}
	product_info($final_home);
	return $self;
}

sub test_coinbase_client {
	my $coinbase_client = shift;
	my $response = product_info( $coinbase_client->products->get_products());
	return defined($response) ? 1 : undef;		
}

sub setup_coinbase_client {
	my $self = shift;
	my $cc = shift;

	sub store_client {
		my $coinbase_client = shift;
		return undef unless defined(test_coinbase_client($coinbase_client));
		coinbase_client($coinbase_client);
	}

	foreach (@{$cc}) {
		store_client($_)
	}

	return $self;
}
sub parser_my_rest_api_order {
	my $o = shift;
	$o->{type} = delete($o->{status});
	remove_excess_zeros_from_price($o);
	$o->{remaining_size} = (delete($o->{size}) - delete($o->{filled_size}));
	$o->{order_id} = delete($o->{id});
}

sub store_my_order_list {
	my $self = shift;
	my $orders = shift;
	return undef unless (ref($orders) =~ /ARRAY/);
	foreach my $o (@{$orders}) {
		next unless $o->{status} eq 'open';
		parser_my_rest_api_order($o);
		store_order($o);
	}
	return $self;
}

sub get_my_open_order_list {
	my ($self, $orders) = (shift, cc_list_orders());
	return $self->store_my_order_list($orders);
}

sub get_coinbase_product_list {
	my ($self, $product_list) = (shift, cc_get_products());
	$self->parse_product_info($product_list)
}

sub new {
	Toyhouse::Client::request
		->set_max_rps(10);

	my $self = shift;
	$self = bless {@_}, $self;
	$self->setup_coinbase_client($self->{cc}) if $self->{cc};

	if (defined(coinbase_client())) {
		$self->get_my_open_order_list();
		$self->get_coinbase_product_list();
	}
	else {
		
		# if we don't have a working client, we should get it from the user	
		$self->parse_product_info($self->{product_info}) if $self->{product_info};
		$self->store_my_order_list($self->{my_open_orders}) if $self->{my_open_orders};
	}

	return $self;
}

sub start_reading_pipe {
	my $self = shift;
	my $user_open_work = [];
	my $user_filled_work = [];
	my $user_change_work = [];
	my $work = [];
	$self->{read_pipe} = {@_}->{read_pipe}->{read_pipe};

	$self->{w} = AnyEvent->io (fh => *{$self->{read_pipe}}, poll => "r", cb => sub {
		$self->{w_counter}++;
		my $pipe = $self->{read_pipe};

		### Prioritize test
		if (defined(my $input = <$pipe>)) {
			if ($input eq "\004\n") { # end transmission # must exit as quickly as possible
				close($pipe);
				$self->{w} = undef;
				print STDERR "ending ws session\n";
				EV::break;
				return;
			}
			else {
				my $test_work = Toyhouse::Core::decode_json($input);
				if (type(user_id => $test_work)) {
					my $RECEIVED = received_book();
					if (type(reason => $test_work) && ($test_work->{reason} eq 'filled')) {
						error $LOGGER "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!priority: user_id_filled";
						push @{$user_filled_work}, $test_work;
					}
					elsif (($test_work->{type} eq 'match') && $RECEIVED->{$test_work->{taker_order_id}}) {
						# creating an open order for 'my' taker limit order
						$RECEIVED->{$test_work->{taker_order_id}}->{remaining_size} = delete($RECEIVED->{$test_work->{taker_order_id}}->{size});
						$RECEIVED->{$test_work->{taker_order_id}}->{type} = 'open';

						error $LOGGER "We were TAKER on $test_work->{taker_order_id}\n";

						push @{$user_filled_work}, delete($RECEIVED->{$test_work->{taker_order_id}});
					}
					elsif (($test_work->{type} eq 'received') && ($test_work->{order_type} eq 'limit')) {
						$RECEIVED->{$test_work->{order_id}} = $test_work;
					}
					else {
						delete($RECEIVED->{$test_work->{order_id}}) if $test_work->{order_id} && $RECEIVED->{$test_work->{order_id}};
						push @{$work}, $test_work;			
					}
					received_book($RECEIVED);
				}
				elsif ($test_work->{test_output}) {
					print STDERR $test_work->{test_output}."\n";
					return;
					#next;
				}
				else {
					push @{$work}, $test_work;			
				}

				my ($o, $response);
				my $idle_watcher; $idle_watcher ||= AnyEvent->idle (cb => sub {
					if (scalar(@{$user_filled_work})) {
						$o = shift(@{$user_filled_work});
						$response = store_order($o);
					}
					elsif (scalar(@{$work})) {
						$o = shift(@{$work});
						$response = store_order($o);
					}
					else {
						undef $idle_watcher
					}

					if (defined($response) && (ref($response) =~ /ARRAY/)) {
						# order failed, push into non-priority list
						while (scalar(@{$response})) {
							push @{$work}, shift(@{$response});
						}
					}
				});
			}
		}
	}); EV::run;
};

sub begin {
	EV::run
}

our $begin = sub {EV::run};

1;