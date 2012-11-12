#!/usr/bin/perl  -w
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_base;
use oss_utils;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/repair_ox_accounts.pl [OPTION]'."\n".
		'This script make sure that the required ldap attributes do exists.'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		"	No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'Optional parameters: '."\n".
		'	-h, --help         Display this help.'."\n".
		'	-d, --description  Display the descriptiont.'."\n";
}
if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	repair_ox_accounts.pl'."\n".
		'DESCRIPTION:'."\n".
		'	This script make sure that the required ldap attributes do exists.'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"		                  : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h, --help        : Display this help.(type=boolean)'."\n".
		'		-d, --description : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}


#Parse parameter
my $oss     = oss_base->new();

my $mesg = $oss->{LDAP}->search( base   => "ou=people,".$oss->{LDAP_BASE},
                       filter => "(uid=admin)",
                       scope  => 'one',
                       attrs  => ['c','oxtimezone','preferredLanguage']
                     );

my $pl = $mesg->entry(0)->get_value('preferredLanguage') || 'DE';
my $c  = $mesg->entry(0)->get_value('c') || 'DE';
my $tz = $mesg->entry(0)->get_value('oxtimezone') || 'Europe/Berlin';

$mesg = $oss->{LDAP}->search( base   => "ou=people,".$oss->{LDAP_BASE},
                       filter => "(!(role=workstations))",
                       scope  => 'one',
                       attrs  => ['userCountry','oxtimezone','preferredLanguage','oxenabled']
                     );

foreach my $entry ( $mesg->entries ) {
  if( ! $entry->exists('userCountry'))
  {
    $oss->{LDAP}->modify( $entry->dn(), add => { userCountry => $c });
    print $entry->dn.": add userCountry $c\n";
  }
  if( ! $entry->exists('oxtimezone'))
  {
    $oss->{LDAP}->modify( $entry->dn(), add => { oxtimezone => $tz }); 
    print $entry->dn.": add oxtimezone $tz\n";
  }
  if( ! $entry->exists('preferredLanguage'))
  {
    $oss->{LDAP}->modify( $entry->dn(), add => { preferredLanguage => $pl }); 
    print $entry->dn.": add preferredLanguage $pl\n";
  }
  if( ! $entry->exists('oxenabled'))
  {
    $oss->{LDAP}->modify( $entry->dn(), add => { oxenabled => "ok" }); 
    print $entry->dn.": add oxenabled ok\n";
  }
  else
  {
    $oss->{LDAP}->modify( $entry->dn(), replace => { oxenabled => "ok" }); 
    print $entry->dn.": replace oxenabled ok\n";
  }
}

$mesg = $oss->{LDAP}->search( base   => "ou=people,".$oss->{LDAP_BASE},
                       filter => "(oxenabled=OK)",
                       scope  => 'one',
                       attrs  => ['dn']
                     );

foreach my $entry ( $mesg->entries ) {
  $oss->{LDAP}->modify( $entry->dn(), replace => { oxenabled => 'ok' });
  print $entry->dn.": oxEnabled ok\n";
}

$oss->destroy();
