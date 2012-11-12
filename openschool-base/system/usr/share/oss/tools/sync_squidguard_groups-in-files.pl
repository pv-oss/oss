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
	print   'Usage: /usr/share/oss/tools/sync_squidguard_groups-in-files.pl [OPTION]'."\n".
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
		'	sync_squidguard_groups-in-files.pl'."\n".
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
my $GROUPS = '';
system("test -e && rm -rf /var/lib/squidGuard/db/custom/groups");
system("mkdir -p  /var/lib/squidGuard/db/custom/groups");
foreach my $type ( ('primary','class','workgroup'))
{
  foreach my $dn ( $oss->get_school_groups($type))
  {
     my $name  = get_name_of_dn($dn);
     my $users = '';
     foreach my $user ( @{$oss->get_users_of_group($dn)} )
     {
	 next if ( $type eq 'class'     && $oss->is_teacher($user) );
         next if ( $type eq 'workgroup' && $oss->is_teacher($user) );
  	 $users .= get_name_of_dn($user)."\n";
     }
     write_file('/var/lib/squidGuard/db/custom/groups/'.$name,$users);
     $GROUPS .= "src $name {\n";
     $GROUPS .= "  userlist custom/groups/$name\n";
     $GROUPS .= "}\n\n";
  }
}
system("chown -R squid /var/lib/squidGuard/db/custom/groups");
system("cp /etc/squid/squidguard.conf /etc/squid/squidguard.conf.back");
my $sgconf = get_file("/etc/squid/squidguard.conf");
$sgconf =~ s/###OSS-GROPS-START[\s|\S]*###OSS-GROUP-END//m;
$GROUPS = "###OSS-GROPS-START
###DO NOT CHANGE THIS LINES
$GROUPS
###OSS-GROUP-END";
$sgconf =~ s#(dbhome /var/lib/squidGuard/db)#$1\n$GROUPS#m;
write_file("/etc/squid/squidguard.conf",$sgconf);
system("rcsquid reload");
