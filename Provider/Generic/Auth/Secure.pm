package Toyhouse::Provider::Generic::Auth::Secure;

BEGIN { 

    require Math::Random::Secure;
    *rand               = *Math::Random::Secure::rand;
    my $max32bit        = 2^32;
    sub nonce {
        rand($max32bit)
    }

    require Digest::SHA;    import Digest::SHA;
    *hmac_sha256        = *Digest::SHA::hmac_sha256;
    *hmac_sha256_hex    = *Digest::SHA::hmac_sha256_hex;
    sub hmac_sha256_hex_w_nonce {
        hmac_sha256_hex(@_, nonce())
    }

    require MIME::Base64;   import MIME::Base64     ();
    *encode_base64      = *MIME::Base64::encode_base64;
    *decode_base64      = *MIME::Base64::decode_base64;

}

1;
