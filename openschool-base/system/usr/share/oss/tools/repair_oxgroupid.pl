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
	print   'Usage: /usr/share/oss/tools/repair_oxgroupid.pl [OPTION]'."\n".
		'Program to repair the users OXGroupID parameters.'."\n\n".
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
		'	repair_oxgroupid.pl'."\n".
		'DESCRIPTION:'."\n".
		'	Leiras ...'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"		                  : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h, --help        : Display this help.(type=boolean)'."\n".
		'		-d, --description : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}

#Parse parameter
my $group;
my $oss     = oss_base->new();

my $mesg = $oss->{LDAP}->search( base   => $oss->{LDAP_BASE},
                       filter => "(objectclass=schoolAccount)",
                       scope  => 'sub',
                       attrs  => ['uid']
                     );

foreach my $entry ( $mesg->entries ) {
  my $dn = $entry->dn;
  print $dn."\n";
  foreach my $group ( @{$oss->get_groups_of_user($dn,1)} )
  {
  	$oss->{LDAP}->modify( $dn, add => {  OXGroupID => $oss->get_attribute($group,'gidnumber') });
  }
}

$oss->destroy();

