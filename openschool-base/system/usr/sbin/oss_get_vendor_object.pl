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

# Global variable
my $connect     = {};
my $XML         = 1;
my $line        ='';
my @dns                = ();
my $configurationKey   = '';
my @configurationValue = ();
my $o                  = '';

# If neccessary read the commandline options
while(my $param = shift)
{
   $XML=0 if( $param =~ /text/i );
}

while(<STDIN>)
{

	$line .= $_;

	# Clean up the line!
	chomp; s/^\s+//; s/\s+$//;
	
	my ( $key, $value ) = split / /,$_,2;

	next if( getConnect($connect,$key,$value));
	
	if( !defined $value  || $value eq  '' )
	{
	        chomp $key;
	        push @dns, $key;
	}
	elsif( $key =~ /^configurationKey$/i )
	{
	      $configurationKey = $value;
	}
	elsif( $key = /^o/i )
	{
	      $o = $value;
	}
}

# Make OSS Connection
if( defined $ENV{SUDO_USER} )
{
   if( ! defined $connect->{aDN} || ! defined $connect->{aPW} )
   {
        $connect->{aDN} = 'anon';
   }
}
my $oss = oss_base->new($connect);


$oss->{XML} = $XML;

if( $oss->get_school_config('SCHOOL_DEBUG') eq 'yes' )
{
  write_file("/tmp/get_room",$line);
}

my $out = '';
foreach my $dn (@dns)
{
    if( $oss->{XML} )
    {
      $out .= hash_to_xml($oss->get_vendor_object_as_hash($dn,$o,$configurationKey));
    }
    else
    {
      $out .= hash_to_text($oss->get_vendor_object_as_hash($dn,$o,$configurationKey));
    }

}
if( $oss->{XML} )
{
  print reply_xml($out);
}
else
{
  print $out;
}

$oss->destroy();
