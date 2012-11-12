#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2005 Peter Varkoly Fuerth, Germany.  All rights reserved
# <peter@varkoly.de>
# Revision: $Rev: 1618 $

BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

$| = 1; # do not buffer stdout

use strict;
use oss_utils;
use oss_base;
use DBI;

my $oss  = oss_base->new();
my $uid  = "";
my $role = "";
my $LANG = "EN";

while(<STDIN>)
{
  my ( $key, $value ) = split / /,$_,2;
  chomp $value;
  if ( $key eq 'uid' )
  {
    $uid = $value;
  }
  if ( $key eq 'role' )
  {
     $role = $value;
  }
  if ( $key eq 'preferredlanguage' )
  {
     $LANG = $value;
  }
}

if ( $role eq 'workstations' || $role eq 'machine' )
{
	$oss->destroy();
	exit;
}
my $USE_OX = $oss->get_school_config("SCHOOL_USE_OX");
my $MAILS  = $oss->get_school_config("SCHOOL_MAILSERVER");
if( $USE_OX =~ /^yes$/i )
{
	my $test = `/sbin/ip addr | grep "$MAILS/"`;
	if( ! $test )
	{
		system("ssh mailserver /srv/www/oss/openxchange/sbin/addusersql_ox --username=$uid --lang=$LANG &> /dev/null");
  	}
	else
	{
		system("/srv/www/oss/openxchange/sbin/addusersql_ox --username=$uid --lang=$LANG &> /dev/null");
	}
}
$oss->destroy();
