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
my @dns                = ();
my $configurationKey   = '';
my @configurationValue = ();
my $o                  = '';
my $connect       = {};

while(<STDIN>)
{
	
    # Clean up the line!
    chomp; s/^\s+//; s/\s+$//;
    
    my ( $key, $value ) = split / /,$_,2;
    
    next if( getConnect($connect,$key,$value));

    if( !defined $value  || $value eq  '' )
    {
    	if( $key ne '' )
    	{
    	  	push @dns, $key;
    	}
    }
    elsif( $key =~ /configurationKey/i )
    {
    	$configurationKey = $value;
    }
    elsif( $key =~ /configurationValue/i )
    {
    	push @configurationValue, $value;
    }
    elsif( $key =~ /^o/i )
    {
    	$o = $value;
    }
}

if( defined $ENV{SUDO_USER} )
{
   if( ! defined $connect->{aDN} || ! defined $connect->{aPW} )
   {
       die "Using sudo you have to define the parameters aDN and aPW\n";
   }
}
my $oss = oss_base->new($connect);


foreach my $dn (@dns)
{
	$oss->create_vendor_object($dn,$o,$configurationKey,\@configurationValue);
}

$oss->destroy();
