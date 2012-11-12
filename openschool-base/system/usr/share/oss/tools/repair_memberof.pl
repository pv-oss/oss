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
	print   'Usage: /usr/share/oss/tools/repair_memberof.pl [OPTION]'."\n".
		'Add missed memeberOf attribute'."\n\n".
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
		'	repair_memberof.pl'."\n".
		'DESCRIPTION:'."\n".
		'	Add missed memeberOf attribute'."\n".
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
  $oss->{LDAP}->modify( $dn, add => { objectclass => 'memberOf' });
  foreach my $group ( @{$oss->get_groups_of_user($dn,1)} )
  {
  	$oss->{LDAP}->modify( $dn, add => { memberOf => $group });
  }
  $oss->add_user_to_group($dn,$oss->get_primary_group_of_user($dn));
}

$oss->destroy();

