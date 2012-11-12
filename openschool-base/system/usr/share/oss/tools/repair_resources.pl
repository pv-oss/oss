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
use Net::Netmask;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/repair_resources.pl [OPTION]'."\n".
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
		'	repair_resources.pl'."\n".
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

my $rbase = 'ou=ResourceObjects,'.$oss->{LDAP_BASE};
my $rgname= 'resourceGroupName=Rooms,'.$rbase;

$oss->{LDAP}->add( $rbase,
		    attr => [
			objectclass => ['top','organizationalUnit'],
			ou => 'ResourceObjects'
		    ]
		);

$oss->{LDAP}->add( $rgname,
		    attr => [ 
		    	objectclass => 'OXResourceGroupObject',
			resourceGroupName => 'Rooms',
			resourceGroupAvailable => 'TRUE',
			resourceGroupDescription => 'Räume',
			]
		);

my $mesg = $oss->{LDAP}->search( base   => "ou=DHCP,".$oss->{LDAP_BASE} ,
                                 filter => "(&(description=*)(objectclass=SchoolRoom))"
                                );
foreach my $entry ( $mesg->entries )
{
    my $desc  = $entry->get_value('description');
    next if ( $desc eq 'ANNON_DHCP' || $desc eq 'ANON_DHCP') ;
    $oss->{LDAP}->add( 'resourceName='.$desc.','.$rbase,
                    attr => [
                        objectclass => 'OXResourceObject',
			resourceName => $desc, 
			resourceAvailable => 'TRUE'
		]
	);

    $oss->{LDAP}->modify( $rgname, add => {resourceGroupMember=>$desc});
}

