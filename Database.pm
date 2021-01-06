package Toyhouse::Database;
use Mojo::Base qw/-strict -signatures/;
use Mojo::mysql;
use Class::Struct( 'Toyhouse::Database' => {
	db => 'Mojo::mysql'
});

{
	no warnings 'redefine';

	sub new($self) {
		$self->db( 
			Mojo::mysql->strict_mode(
				'mysql://'.
				$ENV{DB_USER}. ':'.
				$ENV{DB_PASS}. '@'.
				$ENV{DB_HOST}. '/'.
				$ENV{DB}. ':'.
				$ENV{DB_OPTS}));
	}

}
1