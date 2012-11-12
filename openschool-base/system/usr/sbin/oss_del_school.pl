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
binmode STDIN, ':utf8';
my $connect       = { withIMAP => 1 };

my @dns     = ();

while(<STDIN>)
{
   # Clean up the line!
   chomp; s/^\s+//; s/\s+$//;

   my ( $key, $value ) = split / /,$_,2;

   next if (getConnect($connect,$key,$value));

   if( $_ ne '' )
   {
     push @dns, $_;
   }
}

#Now we make LDAP connections
if( defined $ENV{SUDO_USER} )
{
   if( ! defined $connect->{aDN} || ! defined $connect->{aPW} )
   {
       die "Using sudo you have to define the parameters aDN and aPW\n";
   }
}
my $oss = oss_base->new($connect);

foreach my $dn ( @dns )
{
  $oss->init_sysconfig($dn);
  if( ! $oss->delete_school($dn) )
  {
     print  $oss->{ERROR}->{text}."\n";
  }
}
$oss->destroy();
