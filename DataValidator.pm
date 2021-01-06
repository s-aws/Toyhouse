package Toyhouse::DataValidator;
use Toyhouse::DataValidator::Time;
use Mojo::Base qw/-strict -signatures/;

my $ALPHANUM = '([a-f]|[0-9])+';
my $ANY = '(.++)';
my $BOOLEAN = '(\0|\1|0|1)';
my $BUYSELL = '(buy|sell)';
my $FLOAT = '\d+(\.\d+)?';
my $NUM = '\d++';
my $ORDER_TYPE = '(limit|market)';
my $PRODUCT_ID = '([A-Z]|[0-9]){1,4}\-([A-Z]|[0-9]){3,4}';
my $REASON = '(canceled|filled)';
my $STATUS = '(active|open|pending|settled|done)';
my $TIF = '(GTT|GTC|FOK|IOC)';
my $TYPE = '(received|open|match|done|change|activate|limit|market)';
my $UUID = '([a-f]|[0-9]){8}\-([a-f]|[0-9]){4}\-([a-f]|[0-9]){4}\-([a-f]|[0-9]){4}\-([a-f]|[0-9]){12}';

my $SUB_REGEX_MAP = {
	do{map { $_ => $FLOAT } qw( price stop_price size remaining_size old_size new_size funds old_funds new_funds maker_fee_rate taker_fee_rate trade_id ask bid volume fill_fees filled_size executed_value )},
	do{map { $_ => $ALPHANUM } qw( user_id maker_user_id taker_user_id )},
	do{map { $_ => $UUID } qw( id order_id maker_order_id taker_order_id profile_id maker_profile_id taker_profile_id client_oid )},
	do{map { $_ => $ANY } qw( time created_at done_at )},
	do{map { $_ => $BOOLEAN } qw( private post_only settled )},
	do{map { $_ => $REASON } qw( reason done_reason )},
	product_id => $PRODUCT_ID,
	order_type => $ORDER_TYPE,
	time_in_force => $TIF,
	type => $TYPE,
	side => $BUYSELL,
	status => $STATUS

};

sub validate ($class, $sub_name, $arg=undef) {
	return unless $$arg;
	return if $$arg eq 'subscriptions'; #temporary

	my $regex = $SUB_REGEX_MAP->{ $sub_name };
	die $sub_name. ' '. $$arg. ' does not match /^'. $regex. '$/' unless $$arg =~ /^$regex$/;
	$$arg = Toyhouse::DataValidator::Time->new( 'time' => $$arg )->convert->to_epoch() if ($sub_name =~ /^(time|done_at|created_at)$/);
	#bless $arg, $class # can't remember why I did this
}

1



