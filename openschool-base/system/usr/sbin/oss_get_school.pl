#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_utils;
use oss_base;
binmode STDIN, ':utf8';

# Global variable
my $line        = '';
my $connect     = {};
my $XML         = 1;
my $dn     	= '';
my $scope  	= 'one';
my $filter 	= '';
my $nfilter	= 0;
my $mesg	= undef;
my @attributes	= ();


# If neccessary read the commandline options
while(my $param = shift)
{
  $XML=0 if( $param =~ /text/i )
}

while(<STDIN>)
{

  $line .= $_;

  # Clean up the line!
  chomp; s/^\s+//; s/\s+$//;

  my ( $key, $value ) = split / /,$_,2;

  next if( getConnect($connect,$key,$value));

  if( !$value )
  {
	chomp $key;
	if( $key =~ /^uniqueidentifier=.*/i )
        {
	   $dn = $key;
	}
  }
  elsif ( $key eq 'attributes' )
  {
        @attributes = split / /,$value;
  }
  elsif ( $key eq 'oid' )
  {
	$filter .= '(uniqueidentifier='.$value.')';
  }
  else 
  {
	$filter .= '('.$key.'='.$value.')';
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
my $base   	= $oss->{LDAP_BASE};

if( $oss->get_school_config('SCHOOL_DEBUG') eq 'yes' )
{
  write_file("/tmp/get_school",$line);
}

if( $dn ne '' )
{
	$filter = '(objectclass=School)';
	$scope  = 'base';
	$base   = $dn;
}
elsif ( $filter ne '' )
{
	$filter = '(&(objectclass=School)'.$filter.')';
}
else
{
	$filter = '(objectclass=School)';
}

if( scalar(@attributes) )
{
   $mesg = $oss->{LDAP}->search( 
                          base   => $base,
                          scope  => $scope,
                          filter => $filter,
                          attrs  => \@attributes
                        );
}
else
{
   $mesg = $oss->{LDAP}->search( 
                          base   => $base,
                          scope  => $scope,
                          filter => $filter
                        );
}

if( ! $mesg )
{
        print "ERROR Could not search the school\n";
        exit 1;
}

my $result = $mesg->as_struct;
foreach my $dn ( keys %{$result} )
{
  $oss->init_sysconfig($dn); 
  if( scalar(@attributes) )
  {
	foreach my $key (@attributes)
	{
	   if( $key =~ /^SCHOOL_/ )
	   {
	     push @{$result->{$dn}->{$key}}, $oss->{SYSCONFIG}->{$key};
	   }
	}
  }
  else
  {
	foreach my $key ( keys %{$oss->{SYSCONFIG}} )
	{
	   push @{$result->{$dn}->{$key}}, $oss->{SYSCONFIG}->{$key};
	}
  }
}
print $oss->reply($result);

