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
			"param=s",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/repair_shared_mailboxes_for_procmail.pl [OPTION]'."\n".
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
		'	repair_shared_mailboxes_for_procmail.pl'."\n".
		'DESCRIPTION:'."\n".
		'	Leiras ...'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"		                  : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h, --help        : Display this help.(type=boolean)'."\n".
		'		-d, --description : Display the descriptiont.(type=boolean)'."\n".
		'		    --param       : (Value : "text")'."\n";
	exit 0;
}
my $param = '';
if( defined($options{'param'}) ){
	$param = $options{'param'};
}

# Make LDAP Connection
my $oss = oss_base->new();
#while(my $param = shift)
#{
  if( $param =~ /text/i ) { $oss->{XML}=0; }
#}

my $MY_BASE             =$oss->{LDAP_BASE};


my $mesg = $oss->{LDAP}->search ( base => $MY_BASE, filter=> "objectclass=schoolGroup", attrs=>['cn'] );

foreach my $entry ($mesg->entries)
{
   my $cn = $entry->get_value('cn');
   $oss->{LDAP}->modify(  $entry->dn, replace=> { suseMailCommand=>"\"|/usr/bin/procmail -t -m /etc/imap/procmailrc $cn\"" });
   print "$cn done\n";
}
$oss->destroy();
