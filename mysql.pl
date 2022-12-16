use warnings;
use strict;
use lib;
use Readonly;
use Data::Dumper;

BEGIN {push @INC, '/home/ec2-user/Toyhouse/Toyhouse/lib/'; require Toyhouse::Generated::coinbase}

#
# Testing ideas with mysql and Toyhouse
# This test directory is ./perl/mysql.pl but is included in Toyhouse repo because that is where it will end up residing
#


package database_manager {
	use warnings;
	use strict;

	BEGIN {require DBI; import DBI ()}

	our $table_definition = {
		cb_currency_symbol =>
			['id varchar(4) not null primary key unique', 'name varchar(32) not null unique', 'max_precision float not null', 'min_size float not null',
			'can_be_base boolean default TRUE',	'can_be_quote boolean default FALSE', 'status boolean'],

		cb_products =>
			['id varchar(9) not null primary key unique', 'quote_increment float', 'post_only boolean', 'status boolean', 'status_message varchar(255)', 'quote_currency varchar(4) not null not null', 
			'base_increment float',	'base_max_size float', 'base_min_size float', 'display_name varchar(8)', 'base_currency varchar(4) not null not null', 'margin_enabled boolean', 
			'min_market_funds int unsigned', 'max_market_funds bigint unsigned', 'limit_only boolean', 'cancel_only boolean'],

		cb_orders => 
			['id char(36) not null primary key unique', 'created_at datetime not null default "2000-01-01 00:00:00.000000"', 'product_id varchar(8) not null default "BTC-USD"',
			'profile_id char(36) not null default "00000000-0000-0000-0000-000000000000"', 'side char(4) not null default "buy"', 'type varchar(6) not null default "limit"', 'settled boolean not null default true',
			'foreign key(product_id) references cb_products(id)' ], # example of an element that must be removed

		cb_orders_done => 
			['id char(36) not null', 'executed_value float not null default 0', 'filled_size float not null default 0', 'done_at datetime not null default "2000-01-01 00:00:00.000000"', 
			'fill_fees float not null default 0.0',
			'foreign key(id) references cb_orders(id) on delete cascade'], # example of an element that must be removed

		cb_orders_limit => 
			['id char(36) not null', 'size float not null default 0.0', 'time_in_force char(3) not null default "GTC"', 'price float not null default 0.0',
			'foreign key(id) references cb_orders(id) on delete cascade'], # example of an element that must be removed

		cb_orders_market_size => 
			['id char(36) not null', 'size float not null default 0.0',
			'foreign key(id) references cb_orders(id) on delete cascade'], # example of an element that must be removed

		cb_orders_market_funds => 
			['id char(36) not null', 'funds float not null default 0.0', 'specified_funds float not null default 0.0',
			'foreign key(id) references cb_orders(id) on delete cascade'] # example of an element that must be removed

	};

	sub build_table_definition_hash_from_full_table_definition {
		# { table_name => ['column_name definition'],}
		sub each_in_list {
			my $list = shift;
			my $cb = shift;
			my $result = {};
			foreach (@{$list}) {
				my ($key, $value) = $cb->($_);
				$result->{$key} = $value
			}
			return $result
		}

		my $table_definition_hash = shift;
		my $full_table_definition_hash = 
			each_in_list([keys(%{$table_definition_hash})], sub {
				my $column_name = ();
				my $column_definition = ();
				my $key = shift;

				# We are cleaning up the column list so the remaining elements have the column_name first
				my $clean_array = [];
				for (my $i=0; $i<scalar(@{$table_definition_hash->{$key}}); $i++) {
					if (substr($table_definition_hash->{$key}[$i], 0, 7) ne 'foreign') {
						push @{$clean_array}, $table_definition_hash->{$key}[$i]
					}
				}
				#########################################################################################

				my $result = 
					each_in_list($clean_array, sub {
						my $column_name_and_def_scalar = shift;
						return split_scalar_into_column_definition($column_name_and_def_scalar);
					});
				return $key => $result;
			});

		return $full_table_definition_hash;
	}

	sub split_scalar_into_column_definition {
		my $scalar = shift;
		my $result = ();
		$result = [split(' ', $scalar, 2)];
		return @{$result}
	}

	sub get_table_definition_array {
		my $table_name = shift;
		return $table_definition->{$table_name} if $table_definition->{$table_name} 
	}

	sub get_all_table_definition_names {
		# because order is important
		return ['cb_currency_symbol', 'cb_products', 'cb_orders', 'cb_orders_done', 'cb_orders_limit', 'cb_orders_market_size', 'cb_orders_market_funds']
	}

	sub dsn {
		# database, host, port
		my $dsn_template = 'DBI:mysql:database=%s;host=%s;port=%s';
		return undef unless scalar(@_) == 3;
		return sprintf($dsn_template, @_);
	}

	sub connect {
		# dsn, user, pass
		return undef unless scalar(@_) == 3;
		return DBI->connect(@_);
	}
}

sub connect_to_db {
	my $db = shift;
	my $host = 'localhost'; 
	my $port = '3306'; 
	my $user = $ENV{DB_USER}; 
	my $pass = $ENV{DB_PASS}; 
	my $dsn = ();
	my $generate_dsn = *database_manager::dsn;
	my $connect_to_db = *database_manager::connect;

	$dsn = $generate_dsn->($db, $host, $port);
	return $connect_to_db->($dsn, $user, $pass);
}

sub generate_create_table_statement {
	my $table_name = shift;
	
	sub generate_table_def_from_array {
		my $table_name = shift;
		my $sep_col_defs = ",\n";
		my $final_statement_ready_to_send = ();
		my $column_definition_list = database_manager::get_table_definition_array($table_name);
		$final_statement_ready_to_send = join($sep_col_defs, @{$column_definition_list});
		return $final_statement_ready_to_send
	}

	sub create_table_statement {
		my $table_name = shift; 
		my $table_def_string = shift;
		sprintf('create table %s(%s)', $table_name, $table_def_string);
	}

	my $result = create_table_statement($table_name, generate_table_def_from_array($table_name));
	return $result;
}

sub execute_statement {
	my $sth = shift;
	my $args = @_;
	$sth->execute(@_);
	return $sth
}

sub prepare_statement {
	my $dbh = shift;
	my $statement = shift;
	my $sth = ();
	$sth = $dbh->prepare($statement);
	return $sth;
}

sub drop_table {
	my $dbh = shift;
	my $table_name = shift;
	my $delete_table_statement = 'DROP table ' . $table_name;
	my $sth = prepare_statement($dbh, $delete_table_statement);

	execute_statement($sth);
	print STDERR $dbh->errstr() if $dbh->errstr();
}

sub delete_from_table {
	my $dbh = shift;
	my $table_name = shift;
	my $delete_table_statement = 'DELETE FROM ' . $table_name;
	my $sth = prepare_statement($dbh, $delete_table_statement);

	execute_statement($sth);
	die $dbh->errstr() if $dbh->errstr();
}

sub create_table {
	my $r = $Toyhouse::Core::STATUS;
	my $dbh = shift;
	my $create_table_statement = shift;
	my $sth = prepare_statement($dbh, $create_table_statement);

	execute_statement($sth);
	if ($dbh->errstr) {
		$r = $Toyhouse::Core::STATUS[-1];
	}

	return $r;
}

sub drop_tables_in_reverse {
	my $dbh = shift;
	my $table_list = shift; 
	@$table_list = reverse @$table_list;
	foreach (@$table_list) {
		print STDERR "$_ ";
		drop_table($dbh, $_);
	}
}

sub create_all_tables {
	my $dbh = shift;
	my $table_list = shift;
	foreach (@$table_list) {
		print STDERR "$_ ";
		my $statement = generate_create_table_statement($_);
		my $result = create_table($dbh, $statement);
	}
}

sub list_tables_in_db {
	my $dbh = shift; my $db = shift;
	my $show_statement = "show tables";
	my $table_list_column_name = 'Tables_in_' . $db;
	my $sth = $dbh->prepare($show_statement);
	
	$sth->execute() or die $dbh->errstr();
	my $result_of_query;
	while (my $table = $sth->fetchrow_hashref()) {
		my $tableName = $table->{$table_list_column_name};
		push @$result_of_query, $tableName
	}
	return $result_of_query
}

sub build_array_from_hash_for_db_insert {
	# create a 2d vector to be used in $sth->execute
	# column must correspond to the key in the values_to_be_inserted hash
	my ($values_to_be_inserted, $db_column_list) = @_;
	my $result = []; 
	my $i = 0;
	foreach my $hash (@$values_to_be_inserted) {
		@{$result}[$i] = [];
		foreach my $column_name (@$db_column_list) {
			push @{$result}[$i], $hash->{$column_name}; 
		}
		$i++;
	}
	return $result;
}

sub get_values_qmarts {
	my $value_array_ref = shift;
	my $value = sub {'values('. shift .')'};
	my $value_q_marks = "?" . ",?"x(scalar(@$value_array_ref)-1);
	return $value->($value_q_marks);
}

sub insert_coinbase_data_into_db {
	my ($dbh, $coinbase_product_details_list, $table_name, $all_tables_definition_hash) = @_;
	$table_name = 'cb_' . $table_name;
	my $table_definition = $all_tables_definition_hash->{$table_name};
	my $column_list = [keys(%{$table_definition})];
	my $execute_values = build_array_from_hash_for_db_insert($coinbase_product_details_list, $column_list);
	my $insert = "insert ignore into $table_name(" . join (',',@$column_list) . ") "; #ignore is only temporary
	my $values = get_values_qmarts($column_list);
	my $statement = $insert . $values;
	my $sth = $dbh->prepare($statement);

	foreach my $value_array (@{$execute_values}) {
		print STDERR ".";
		$sth->execute(@$value_array) or die $dbh->errstr();
	}
}

sub get_currencies_from_db {
	my $dbh = shift; 
	my $table = 'currency_symbol';
	my $statement = "select * from $table";
	my $sth = $dbh->prepare($statement);
	$sth->execute() or die $dbh->errstr();

	my $result_hash = {};
	while (my $row = $sth->fetchrow_hashref) {
		$result_hash->{delete($row->{symbol_id})} = $row}

	return $result_hash;
}

sub create_coinbase_client {
	my $auth = shift;
	my $client = Toyhouse::Generated::coinbase->new(pro_api => $auth);
	return $client;
}

sub get_coinbase_currency_list {
	my $client = shift;
	my $currencies = $client->get_currencies;
	return $currencies;
}

sub get_coinbase_order_list {
	my $client = shift;
	$client->set_status("done")->query;
	my $orders = $client->list_orders;
	return $orders;

}

sub get_coinbase_products {
	my $client = shift;
	my $products = $client->get_products;
	return $products
}

sub parse_coinbase_order_type_from_order_list_and_insert_into_db {
	my ($order_list, $dbh, $db_table_definition_hash) = @_;
	print STDERR "parse_coinbase_order_type_from_order_list_and_insert_into_db";

	foreach my $order (@$order_list) {
		insert_coinbase_data_into_db($dbh, [$order], orders => $db_table_definition_hash); #because it currently takes an array

		if ($order->{status}) {
			if ($order->{status} eq 'done')	{
				insert_coinbase_data_into_db($dbh, [$order], orders_done => $db_table_definition_hash); #because it currently takes an array
			}
			if ($order->{type} eq 'limit') {
				insert_coinbase_data_into_db($dbh, [$order], orders_limit => $db_table_definition_hash); #because it currently takes an array
			}
			elsif ($order->{type} eq 'market') {
				if ($order->{size}) {
					insert_coinbase_data_into_db($dbh, [$order], orders_market_size => $db_table_definition_hash); #because it currently takes an array
				}
				elsif ($order->{funds}) {
					insert_coinbase_data_into_db($dbh, [$order], orders_market_funds => $db_table_definition_hash); #because it currently takes an array
				}
			}
		}
	}

	print STDERR "\n";
}

sub main {
	my Readonly $secret = $ENV{CB_SECRET}; my Readonly $passphrase = $ENV{CB_PASSPHRASE}; my Readonly $key = $ENV{CB_KEY}; 
	my Readonly $auth = {secret => $secret, passphrase => $passphrase, key => $key};
	my Readonly $db = 'toyhouse';

	my $MAX_REQUESTS_PER_SECOND = 2;
	my $MAX_PAGINATION_COUNT = 2;

	# Silently fails when rps is too high, need to fix
	Toyhouse::Client::request->set_max_rps($MAX_REQUESTS_PER_SECOND); # modify the requests per second
	Toyhouse::Client::request->set_max_pagination_requests($MAX_PAGINATION_COUNT);
	Toyhouse::Client::request->enable_verbose_pagination();



	my $coinbase = create_coinbase_client($auth);
	my $dbh = connect_to_db($db);

	$coinbase->accounts; # set accounts as api

	print STDERR "get_coinbase_products";
	my $product_list = get_coinbase_products($coinbase);
	print STDERR "\n";

	print STDERR "get_coinbase_currency_list";
	my $currency_list = get_coinbase_currency_list($coinbase);
	print STDERR "\n";

	print STDERR "get_coinbase_order_list";
	$coinbase->orders; # set orders as api
	my $order_list = get_coinbase_order_list($coinbase);
	print STDERR "\n";

	my $db_table_definition_hash = database_manager::build_table_definition_hash_from_full_table_definition($database_manager::table_definition);

	print STDERR "dropping table(s): ";
	drop_tables_in_reverse($dbh, database_manager::get_all_table_definition_names());
	print STDERR "\n";

	print STDERR "creating table(s): ";
	create_all_tables($dbh, database_manager::get_all_table_definition_names());
	print STDERR "\n";

	print STDERR "database work";
	insert_coinbase_data_into_db($dbh, $product_list, products => $db_table_definition_hash);
	print STDERR "\n";
	insert_coinbase_data_into_db($dbh, $currency_list, currency_symbol => $db_table_definition_hash);
	print STDERR "\n";
	parse_coinbase_order_type_from_order_list_and_insert_into_db($order_list, $dbh, $db_table_definition_hash);
	print STDERR "\n";
}

main();

1;
