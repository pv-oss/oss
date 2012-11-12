#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2009 Peter Varkoly Fuerth, Germany.  All rights reserved
# <peter@varkoly.de>
# Revision: $Rev: 1618 $

BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

$| = 1; # do not buffer stdout

use strict;

my $uid         = "";
my $dn          = "";
my $userpassword= "";
my $role        = "";

while(<STDIN>)
{
	my ( $key, $value ) = split / /,$_,2;
	chomp $value; $key = lc( $key );
	if ( $key eq 'userpassword' )
	{
		$userpassword = $value;
	}
	if ( $key eq 'role' )
	{
		$role = $value;
	}
	if ( $key eq 'uid' )
	{
		$uid = $value;
	}
}
if( $role =~ /sysadmins/ )
{
	system("/usr/bin/htpasswd2 -cb /etc/nagios/htpasswd.users $uid '$userpassword'");
}

