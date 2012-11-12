#!/usr/bin/perl  -w
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# (c) 2011 EXTIS GmbH
# Revision: $Rev: 1535 $
BEGIN{
    push @INC,"/usr/share/oss/lib"
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
			"force",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/clean-up-sambaUserWorkstations.pl [OPTION]'."\n".
		'Clean up the sambaUserWorkstations attribute.'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		"	No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'Optional parameters : '."\n".
		'       -h,  --help         Display this help.'."\n".
		'       -d,  --description  Display the descriptiont.'."\n".
		'	     --force        Force.'."\n";
}

if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	clean-up-sambaUserWorkstations.pl'."\n".
		'DESCRIPTION:'."\n".
		'	Clean up the sambaUserWorkstations attribute.'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"                         : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h,  --help        : Display this help.(type=boolean)'."\n".
		'		-d,  --description : Display the descriptiont.(type=boolean)'."\n".
		'		     --force       : Force.(type=boolean)'."\n";
	exit 0;
}

my $force = 0;
if( defined($options{'force'}) ){
        $force = 1;
}

my $oss   = oss_base->new();

# Read some values from rcconfig
my $allow_multiple_login          = $oss->get_school_config("SCHOOL_ALLOW_MULTIPLE_LOGIN")          =~ /yes/i ? 1:0;
my $allow_students_multiple_login = $oss->get_school_config("SCHOOL_ALLOW_STUDENTS_MULTIPLE_LOGIN") =~ /yes/i ? 1:0;

my $smbstatus = cmd_pipe("/usr/bin/smbstatus -b","");

my $LoggedOnByUID = {};
my $LoggedOnByCN  = {};

foreach( split /\n/,$smbstatus )
{
	if( /^\d+\s+(\S+)\s+(\S+)\s+(\S+)\s+\((\d+\.\d+\.\d+\.\d+)\)/ )
	{
		$LoggedOnByUID->{"$1-LOGGED_ON=$4"} = 1;
		$LoggedOnByCN->{"$3-LOGGED_ON=$1"}  = 1;
	}
}
#First we clean up the user accounts
my $mesg = $oss->{LDAP}->search( base   => $oss->{LDAP_BASE},
                       		 filter => "(&(!(role=workstations))(objectclass=sambaSamAccount))",
		       		 scope  => 'sub',
		                 attrs  => ['sambaUserWorkstations','configurationValue']
		     );

foreach my $entry ( $mesg->entries ) {
	my @todelete = ();
	my $uid      = get_name_of_dn($entry->dn);
	foreach( $entry->get_value('configurationValue') )
	{
		if( /^LOGGED_ON*/ && ! defined $LoggedOnByUID->{"$uid-$_"} )
		{
			push @todelete, $_;
		}
	}
	if( scalar( @todelete ) )
	{
		$oss->{LDAP}->modify( $entry->dn, delete => { configurationValue => \@todelete } );
		print $oss->get_attribute( $entry->dn, 'cn' )." has not logged off correctly\n";
	}
	#The sambaUserWorkstations attribut is mostly set by guest accounts.
	next if( $oss->is_guest( $entry->dn ));
	next if( !$force && $allow_students_multiple_login && $oss->is_student( $entry->dn )); 
	next if( !$force && $allow_multiple_login          && !$oss->is_student( $entry->dn )); 
	$oss->{LDAP}->modify( $entry->dn, delete => { sambaUserWorkstations => [] } );
}

#Now we clean up the workstation accounts
$mesg = $oss->{LDAP}->search( base   => $oss->{SYSCONFIG}->{DHCP_BASE},
                       		 filter => "(&(configurationValue=LOGGED_ON*)(objectclass=SchoolWorkstation))",
		       		 scope  => 'sub',
		                 attrs  => ['configurationValue']
		     );

foreach my $entry ( $mesg->entries ) {
	my @todelete = ();
	my $cn       = get_name_of_dn($entry->dn);
	foreach( $entry->get_value('configurationValue') )
	{
		if( /^LOGGED_ON*/ && ! defined $LoggedOnByCN->{"$cn-$_"} )
		{
			push @todelete, $_;
		}
	}
	if( scalar( @todelete ) )
	{
		$oss->{LDAP}->modify( $entry->dn, delete => { configurationValue => \@todelete } );
		print "On workstation ".$oss->get_attribute( $entry->dn, 'cn' )." was logged on: ".join(",",@todelete)."\n";
	}
}
