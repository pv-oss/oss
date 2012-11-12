#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2005 Peter Varkoly Fuerth, Germany.  All rights reserved
# <peter@varkoly.de>

BEGIN{
    push @INC,"/srv/www/admin/lib";
    push @INC,"/usr/share/oss/lib/";
}

$| = 1; # do not buffer stdout

use strict;
use Net::LDAP;
use Utils;
use oss_utils;

my $uid = shift;

if( !defined $uid || $uid eq '' )
{
	die "Usage: /usr/sbin/oss_add_user_egroupware.pl uid\n";
}

my ($base, $host, $port) = parse_file("/etc/openldap/ldap.conf", "BASE", "HOST", "PORT");
if(!$host)
{
 $host = 'ldap';
}
if(!$port)
{
 $port = '389';
}

my $ldap =  Net::LDAP->new($host, port => $port , version => 3);

my $result = $ldap->search(
                base   => 'ou=people,'.$base,
                filter => "(uid=$uid)",
		scope  => 'one',
                attr   => ['uidNumber','OXGroupID']
        );


my $mysql = '';
foreach my $entry ($result->all_entries)
{
	my $uidNumber = $entry->get_value('uidNumber');
	foreach my $gid ($entry->get_value('OXGroupID'))
	{
		$mysql .= "INSERT INTO egw_acl VALUES ('phpgw_group','$gid',$uidNumber,1);\n";
	}
}
my $TMPFILE = write_tmp_file($mysql);
system("mysql egroupware < $TMPFILE");
system("rm $TMPFILE");
