#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use Net::LDAP;
use Net::LDAP::Entry;
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
	print   'Usage: /usr/share/oss/tools/set_addressbookCN.pl [OPTION]'."\n".
		'Leiras ....'."\n\n".
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
		'	set_addressbookCN.pl'."\n".
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

# Make LDAP Connection
my $oss = oss_base->new();
my $MY_BASE = $oss->{LDAP_BASE};

my $mesg = $oss->{LDAP}->search ( base => $MY_BASE, filter=> "objectclass=schoolAccount", attrs=>['sn','givenname'] );

foreach my $entry ($mesg->entries)
{
   my $sn = $entry->get_value('sn');
   my $gn = $entry->get_value('givenname');
   $oss->{LDAP}->modify(  $entry->dn, add=> { addressbookCN => "$sn, $gn" });
   print "$sn, $gn done\n";
}
$oss->destroy();
