#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2005 Peter Varkoly Fuerth, Germany.  All rights reserved.
#
# $Id: oss_set_passwd.pl,v 1.6 2007/02/09 17:58:12 pv Exp $
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
			"times=s",
			"reset",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/set_default_access_for_rooms.pl [OPTION]'."\n".
		'This script sets the default access for the rooms.'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		'	    --times        Comma separated list of times when the default access have to be set. (Ex: --times=08:00,10:05,11:00)'."\n".
		'Optional parameters: '."\n".
		'	-h, --help         Display this help.'."\n".
		'	-d, --description  Display the descriptiont.'."\n".
		'	    --reset        Remove all other assigned times entries for DEFAULT SETTINGS.'."\n";
}
if (!$result && ($#ARGV != -1)){
	usage(); exit 1;
}
if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	set_default_access_for_rooms.pl'."\n".
		'DESCRIPTION:'."\n".
		'	This script sets the default access for the rooms.'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		'		    --times       : Comma separated list of times when the default access have to be set.(Ex: --times=08:00,10:05,11:00) (type=string)'."\n".
		'	OPTIONAL:'."\n".
		'		-h, --help        : Display this help.(type=boolean)'."\n".
		'		-d, --description : Display the descriptiont.(type=boolean)'."\n".
		'		    --reset       : Remove all other assigned times entries for DEFAULT SETTINGS.(type=boolean)'."\n";
	exit 0;
}
my $reset  = 0;
my $times  = 0;
if ( defined($options{'times'}) )
{
	$times=$options{'times'};
}else{
	usage(); exit 0;
}
if ( defined($options{'reset'}) ){
	$reset=1;
}

# Make LDAP Connection
my $oss = oss_base->new();

##############################################################################
# now we start to work
my $result = $oss->{LDAP}->search( base   => $oss->{SYSCONFIG}->{DHCP_BASE},
                                       scope   => 'sub',
                                       filter  => '(&(Objectclass=SchoolRoom)(description=*)(!(description=ANON_DHCP)))'
                              );
foreach my $room ( $result->all_entries )
{
    if( $reset )
    {
    	my @sacs = $room->get_value('serviceAccesControl');
	foreach (@sacs)
	{
	    if( ! /^DEFAULT/ && /DEFAULT/ )
	    {
	        $oss->{LDAP}->modify( $room->dn, delete => {serviceAccesControl => $_ } );
	    }
	}
    }
    foreach ( split /,/,$times )
    {
	$oss->{LDAP}->modify( $room->dn, add => {serviceAccesControl => "$_ DEFAULT" } );
    }
}

$oss->destroy();
