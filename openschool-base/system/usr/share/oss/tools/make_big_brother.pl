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
			"ip=s",
			"uid=s",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/make_big_brother.pl [OPTION]'."\n".
		'Leiras.......'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		'	     --ip            IP address.'."\n".
		'	     --uid           User name.'."\n".
		'Optional parameters : '."\n".
		'	-h,  --help          Display this help.'."\n".
		'	-d,  --description   Display the descriptiont.'."\n";
}

if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	make_big_brother.pl'."\n".
		'DESCRIPTION:'."\n".
		'	Leiras ....'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		'		     --ip            : IP address.(type=string)'."\n".
		'		     --uid           : User name.(type=string)'."\n".
		'	OPTIONAL:'."\n".
		'		-h,  --help          : Display this help.(type=boolean)'."\n".
		'		-d,  --description   : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}
my $ip   = undef;
my $uid  = undef;
if( defined($options{'ip'}) ){
	$ip = $options{'ip'};
}else{
	usage(); exit;
}
if( defined($options{'uid'}) ){
        $ip = $options{'uid'};
}else{
        usage(); exit;
}

my $oss = oss_base->new();
my $dn     = $oss->get_workstation($ip);
my $roomdn = get_parent_dn($dn);
my $fname  = `/usr/sbin/oss_get_home $uid`.'/bin/bigbrother.reg';
open(FILE,">$fname");  
print FILE 'Windows Registry Editor Version 5.00
[-HKEY_LOCAL_MACHINE\SOFTWARE\BigBrother]
[HKEY_LOCAL_MACHINE\SOFTWARE\BigBrother]
';
my $res  = $oss->{LDAP}->search( base   => $roomdn,
                           filter => "(objectclass=dhcpHost)",
                           scope  => 'one'
                         );

foreach my $entry ( $res->entries ) 
{
    print FILE "[HKEY_LOCAL_MACHINE\\SOFTWARE\\BigBrother\\".$entry->get_value('cn')."]\n";
}
close(FILE); 

