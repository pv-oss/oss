#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Revision: $Rev: 1618 $

BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_utils;

my $adminpassword = '';
my $oid           = '';
my $SQL           = '';
my $sqlpw         = `/usr/sbin/oss_get_admin_pw`;

while(<STDIN>)
{
  my ( $key, $value ) = split / /,$_,2;
  chomp $value;

  if( $key     =~ /^adminpassword$/i )
  {
    $adminpassword = $value;
  }
  elsif ( $key =~ /^uniqueidentifier$/i)
  {
    $oid = $value;
  }

}

#Creatinig the database
$SQL="create database web$oid;
grant all privileges on web$oid.* to '$oid-webadmin'\@'localhost' identified by '$adminpassword';";
my $OUTFILE = write_tmp_file($SQL);

system("mysql -p$sqlpw < $OUTFILE");
#system("rm $OUTFILE");
