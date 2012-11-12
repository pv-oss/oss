#!/usr/bin/perl  -w
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# (c) 2011 EXTIS GmbH
# Revision: $Rev: 1711 $
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
	print   'Usage: /usr/share/oss/tools/repair_mailacceptaddress.pl [OPTION]'."\n".
		'A tool to reparir obl. mailaddress some clean ups.'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		"	No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
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
		'	repair_mailacceptaddress.pl'."\n".
		'DESCRIPTION:'."\n".
		'	A tool to reparir obl. mailaddress some clean ups.'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"		                     : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h,  --help          : Display this help.(type=boolean)'."\n".
		'		-d,  --description   : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}

#Parse parameter
my $oss     = oss_base->new();

my $domain = $oss->get_school_config('SCHOOL_DOMAIN');

my $mesg = $oss->{LDAP}->search( base   => "ou=people,".$oss->{LDAP_BASE},
                       filter => "(!(role=workstations))",
                       scope  => 'one',
                       attrs  => ['uid']
                     );

foreach my $entry ( $mesg->entries ) {
  my $uid = $entry->get_value('uid');
  $oss->{LDAP}->modify( $entry->dn(), add => { susemailacceptaddress => $uid.'@'.$domain });
  print $entry->dn."\n";
}

$oss->destroy();

