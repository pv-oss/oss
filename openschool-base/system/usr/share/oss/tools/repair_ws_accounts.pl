#!/usr/bin/perl  -w

BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
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
	print   'Usage: /usr/share/oss/tools/repair_ws_accounts.pl [OPTION]'."\n".
		"This script corrects the workstation accounts.\n".
		"It makes sure, that the workstation accounts can not set the password an may only logon on the own workstation.\n".
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
		'	repair_ws_accounts.pl'."\n".
		'DESCRIPTION:'."\n".
		"	This script corrects the workstation accounts.\n".
		"       It makes sure, that the workstation accounts can not set the password an may only logon on the own workstation.\n".
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

my $mesg = $oss->{LDAP}->search( base   => "ou=people,".$oss->{LDAP_BASE},
                       filter => "(role=workstations)",
		       scope  => 'one',
		       attrs  => ['uid']
		     );

foreach my $entry ( $mesg->entries ) {
  my $uid = $entry->get_value('uid');
  $oss->{LDAP}->modify( $entry->dn(), add => { sambaUserWorkstations => $uid });
  $oss->{LDAP}->modify( $entry->dn(), add => { sambaPwdCanChange => "31622400000" });
  $oss->{LDAP}->modify( $entry->dn(), replace => { sambaPwdCanChange => "31622400000" });
  print $entry->dn."\n";
}

