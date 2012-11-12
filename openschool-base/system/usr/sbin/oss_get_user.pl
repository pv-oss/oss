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
my $connect     = {};
my $XML         = 1;
my $line        ='';
my $mesg	= '';
my @dns         = ();
my $dn          = '';
my $uid         = '';
my $oid         = '';
my $sDN         = '';
my $filter      = '';
my @attributes  = ();
my $scope       = 'sub';

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
    
    if( !$value )
    {
          chomp $key;
          if( $key =~ /^uid=.*/i )
          {
            push @dns, $key;
          }  
    }
    elsif ( $key eq 'filter' )
    {
          $filter = $value;
    }
    elsif ( $key eq 'sDN' )
    {
          $sDN = $value;
    }
    elsif ( $key eq 'oid' )
    {
          $oid = $value;
    }
    elsif ( $key eq 'uid' )
    {
          $uid = $value;
          $filter .= '('.$key.'='.$value.')';
    }
    elsif ( $key eq 'attributes' )
    {
          @attributes = split / /,$value;
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

if( $oss->get_school_config('SCHOOL_DEBUG') eq 'yes' )
{
  write_file("/tmp/get_user",$line);
}


if( ! scalar(@attributes) )
{
  @attributes = @{$oss->{DEFAULT_USER_ATTRIBUTES}};
}

my $base = $oss->{LDAP_BASE};
if( ! scalar( @dns ) )
{

	if( $oid ne '' )
	{
	  $base  = $oss->get_school_base($oid);
	  $scope = 'one';
	  if( $uid ne '' )
	  {
	    $dn = $oss->get_user_dn($uid,$base);
	  }
	  $base  = 'ou=people,'.$base;
	}
	elsif( $sDN ne '' )
	{
	  $base  = $sDN;
	  $scope = 'one';
	  if( $uid ne '' )
	  {
	    $dn = $oss->get_user_dn($uid,$base);
	  }
	  $base  = 'ou=people,'.$base;
	}

	if( defined $dn && $dn ne '' )
	{
		$base   = $dn;
		$scope  = 'base';
		$filter = '(objectclass=SchoolAccount)';
	}
	elsif ( $filter ne '' ) 
	{
		$filter = '(&(objectclass=SchoolAccount)'.$filter.')';
	}
	else
	{
		$filter = '(objectclass=SchoolAccount)';
	}

	$mesg = $oss->{LDAP}->search( base   => $base,
				  scope  => $scope,
				  filter => $filter,
				  attrs  => [ 'dn' ] 
				);

	if( ! $mesg )
	{
		print "ERROR Could not search the user\n";
		exit 1;
	}
	my $result = $mesg->as_struct;
        foreach my $dn ( keys %$result )
	{
	   push @dns, $dn;
	}
}
my $out = '';
foreach my $dn (@dns)
{
    if( $oss->{XML} ) 
    {
      $out .= hash_to_xml({ $dn => $oss->get_user($dn,\@attributes)});
    }
    else
    {
      $out .= hash_to_text({ $dn => $oss->get_user($dn,\@attributes)});
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
exit;
