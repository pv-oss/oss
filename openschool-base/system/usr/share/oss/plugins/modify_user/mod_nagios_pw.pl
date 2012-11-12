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
use oss_utils;
use oss_base;

my $oss         = oss_base->new();
my $uid         = "";
my $dn          = "";
my $userpassword= "";

while(<STDIN>)
{
	my ( $key, $value ) = split / /,$_,2;
	chomp $value; $key = lc( $key );
	if( !defined $value)
	{
		chomp  $key;
		$dn  = $key;
		$uid = get_name_of_dn($dn);
	}
	if ( $key eq 'userpassword' )
	{
		$userpassword = $value;
	}
}
my $role = $oss->get_attribute($dn,'role');
if( $role =~ /sysadmins/ )
{
	system("/usr/bin/htpasswd2 -cb /etc/nagios/htpasswd.users $uid '$userpassword'");
}
$oss->destroy();

