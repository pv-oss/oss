#!/usr/bin/perl  -w
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib"
}

use strict;
use oss_base;
use Time::Local;
use Getopt::Long;

my $uid='*';
#Parse parameter
my %options    = ();
my $result = GetOptions(\%options,
			"uid=s",
			"help",
			"description",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/reset_password_age.pl [OPTION]'."\n".
		'Script to set password age attributes.'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		"	No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'Optional parameters: '."\n".
		'	-u, --uid <uid>    Username. If not set all user will be reseted.'."\n".
		'	-h, --help         Display this help.'."\n".
		'	-d, --description  Display the descriptiont.'."\n";
}
if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if ( defined($options{'uid'}) ){
	$uid=$options{'uid'};
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	reset_shadow.pl'."\n".
		'DESCRIPTION:'."\n".
		'	Script to set shadowlastchange attribute.'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"		                  : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-u, --uid <uid>   : Username. If not set all user will be reseted.'."\n".
		'		-h, --help        : Display this help.(type=boolean)'."\n".
		'		-d, --description : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}

my $oss  = oss_base->new();
my $time            = timelocal(localtime());
my $days_since_1970 = int($time / 3600 / 24);
my $mesg = $oss->{LDAP}->search( base   => $oss->{LDAP_BASE},
                       filter => "(&(objectclass=sambaSamAccount)(uid=$uid))",
		       scope  => 'sub',
		       attrs  => ['shadowlastchange']
		     );

foreach my $entry ( $mesg->entries ) {
  if( $entry->exists('shadowlastchange') ) {
     $oss->{LDAP}->modify( $entry->dn(), replace => { shadowlastchange=>$days_since_1970 });
     print $entry->dn()." corrected shadowlastchange\n";
  }
  else
  {
     $oss->{LDAP}->modify( $entry->dn(), add => { shadowlastchange=>$days_since_1970 });
     print $entry->dn()." added shadowlastchange\n";
  }
  $oss->{LDAP}->modify( $entry->dn(), replace => { sambapwdlastset=>$time });
}
