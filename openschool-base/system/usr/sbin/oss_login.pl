#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_base;
use oss_utils;
binmode STDIN, ':utf8';

my $dn               = '';
my $uid              = '';
my $oid              = '';
my $password         = '';
my $remote           = '127.0.0.1';
my $session          = 0;
my $pref             = '';
my $result;

#-----------------------------------------------------------------------------
# Initialisierung
#
my $oss = oss_base->new();
my $DEBUG               = 0;
if( $oss->get_school_config('SCHOOL_DEBUG') eq 'yes' )
{ 
  $DEBUG = 1;
}
open(OUT,">/tmp/login") if($DEBUG);

while(<STDIN>)
{

  print OUT if($DEBUG);
  # Clean up the line!
  chomp; s/^\s+//; s/\s+$//;

  my ( $key, $value ) = split / /,$_,2;
  if( $key eq 'uid' )
  {
	$uid = $value;
  }
  elsif ( $key eq 'oid' )
  {
	$oid = $value;
  }
  elsif ( $key eq 'userpassword' )
  {
	$password = $value;
  }
  elsif ( $key eq 'remote' )
  {
	$remote = $value;
  }
  elsif ( $key eq 'session' )
  {
	$session = $value;
  }
}

print OUT "\n$dn,$password,$remote,$session\n" if($DEBUG);
close(OUT) if($DEBUG);
# First we have to search the school prefix;
if( $oid ne '' )
{
  my $sdn = $oss->get_school_base($oid);
  $dn = $oss->get_user_dn($uid,$sdn);
}
else
{
  $dn = $oss->get_user_dn($uid);
}

if( $result = $oss->login($dn,$password,$remote,$session) )
{
  print $oss->reply($result);
  exit 0;
}
else
{
  print STDERR $oss->{ERROR}->{text};
  exit 1;
}
