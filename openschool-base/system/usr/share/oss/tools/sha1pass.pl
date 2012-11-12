#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

use bytes;
use Digest::SHA1;
use MIME::Base64;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
			"pass=s",
			"salt=s",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/sha1pass.pl [OPTION]'."\n".
		'Leiras .......'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		'	     --pass          Password.'."\n".
		'	     --salt          Salt.'."\n".
		'Optional parameters: '."\n".
		'	-h,  --help          Display this help.'."\n".
		'	-d,  --description   Display the descriptiont.'."\n";
}
if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) )
{
	print   'NAME:'."\n".
		'	sha1pass.pl'."\n".
		'DESCRIPTION:'."\n".
		'	Leiras ....'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		'		     --pass          : Password.(type=string)'."\n".
		'		     --salt          : Salt.(type=string)'."\n".
		'       OPTIONAL:'."\n".
		'		-h,  --help          : Display this help.(type=boolean)'."\n".
		'		-d,  --description   : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}
my $pass = undef;
my $salt = undef;
if( defined($options{'pass'}) ){
	$pass = $options{'pass'};
}else{
	usage(); exit;
}
if( defined($options{'salt'}) ){
	$salt = $options{'salt'};
}else{
	usage(); exit;
}

sub random_bytes($) {
    my($n) = @_;
    my($v, $i);
    
    if ( open(RANDOM, '<', '/dev/random') ||
	 open(RANDOM, '<', '/dev/urandom') ) {
	read(RANDOM, $v, $n);
    } else {
	# No real RNG available...
	srand($$ ^ time);
	$v = '';
	for ( $i = 0 ; $i < $n ; $i++ ) {
	    $v .= ord(int(rand() * 256));
	}
    }

    return $v;
}


#($pass, $salt) = @ARGV;

$salt = $salt || MIME::Base64::encode(random_bytes(6), '');
$pass = Digest::SHA1::sha1_base64($salt, $pass);

print '$4$', $salt, '$', $pass, "\$\n";
