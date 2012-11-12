#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_utils;
use oss_base;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/add_users_to_joomla.pl [OPTION]'."\n".
		'With this script we can add the users on the OSS server to the joomla.'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		"	No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'Optional parameters : '."\n".
		'	-h, --help         Display this help.'."\n".
		'	-d, --description  Display the descriptiont.'."\n";
}
if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	add_users_to_joomla.pl'."\n".
		'DESCRIPTION:'."\n".
		'	With this script we can add the users on the OSS server to the joomla.'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"		                  : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h, --help        : Display this help.(type=boolean)'."\n".
		'		-d, --description : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}

# Initialisierung
#
my $oss = oss_base->new();

foreach my $dn ( @{$oss->get_entries_dn("(&(objectclass=schoolaccount)(!(role=workstations)))")} )
{
   my $entry = $oss->get_entry($dn);
   my $command  = "echo \"uid ". $entry->{'uid'}->[0]."\n";
   $command  .= "userpassword ". $entry->{'uid'}->[0]."\n";
   $command  .= "givenname ". $entry->{'givenname'}->[0]."\n";
   $command  .= "sn ". $entry->{'sn'}->[0]."\n";
   $command  .= "mail ". $entry->{'mail'}->[0]."\"|/usr/share/oss/plugins/add_user/joomla_oss_add_user.sh\n";
   print "ADD USER ".$entry->{'uid'}->[0]." TO JOOMLA\n";
   system($command);
}
$oss->destroy;

