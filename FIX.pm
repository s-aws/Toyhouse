package Toyhouse::FIX;
use warnings;
use strict;
use Data::Dumper;
use Toyhouse::Auth::signature;
use FIX::Lite;

sub new {
	my $fix = FIX::Lite->new(
		Versoin 	=> "FIX42",
		Host 		=> 	'fix.pro.coinbase.com',
		Port		=> 4198,
		Debug 		=> 1,
		Timeout 	=> 10
		) or die "Cannot connect to server: $!";

	my $seq = sub {CORE::state $i = 0; return $i++};

	my $messageToSign = [
		time(),
		"A",
		$seq->(),
		$ENV{CB_KEY},
		"Coinbase",
		$ENV{CB_PASSPHRASE}
	];

	$fix->logon(
		SenderCompID 		=> $ENV{CB_KEY},
		TargetCompID 		=> "Coinbase",
		RawData 			=> Toyhouse::Auth::signature->signFIX(@$messageToSign),
		EncryptedMethod 			=> 0,
		HeartBtInt 					=> 30,
		Debug 						=> 1,
		Password 					=> $ENV{CB_PASSPHRASE},
		CancelOrdersOnDisconnect 	=> "S",
		DropCopyFlag				=> "Y");
	die $! unless $fix->loggedIn();
}
1;
