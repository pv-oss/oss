#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use Data::Dumper;
use oss_base;
use oss_utils;
binmode STDIN, ':utf8';

# Global variable
my $line        = '';
my $connect     = {};
my $XML         = 1;
my $mesg	= undef;
my $dn          = '';
my $cn          = '';
my $oid         = '';
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
        if( $key =~ /^cn=.*/i )
        {
	   $dn = $key;
	}
  }
  elsif ( $key eq 'filter' )
  {
        $filter = $value;
  }
  elsif ( $key eq 'oid' )
  {
	$oid = $value;
  }
  elsif ( $key eq 'cn' )
  {
	$cn = $value;
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

if($connect->{aDN} eq 'anon' && ! scalar(@attributes) )
{
     @attributes = grep( !/quota|mboxacl/, @{$oss->{DEFAULT_GROUP_ATTRIBUTES}} );
}

$oss->{XML} = $XML;

if( $oss->get_school_config('SCHOOL_DEBUG') eq 'yes' )
{ 
    write_file("/tmp/get_group",$line);
}

my $base = $oss->{LDAP_BASE};
if( $oid ne '' && $oid ne  'none' )
{
  $base  = 'ou=group,'.$oss->get_school_base($oid);
  $scope = 'one';
  if( $cn ne '' )
  {
    $dn = $oss->get_group_dn($cn,$oid);
  }
}

if( defined $dn && $dn ne '' )
{
        $base   = $dn;
        $scope  = 'base';
        $filter = '(objectclass=schoolGroup)';
}
elsif ( $filter ne '' )
{
	$filter = '(&(objectclass=schoolGroup)'.$filter.')';
}
else
{
	$filter = '(objectclass=schoolGroup)';
}

if( scalar(@attributes) )
{
   $mesg = $oss->{LDAP}->search( base   => $base,
                          scope  => $scope,
                          filter => $filter,
                          attrs  => \@attributes
                        );
}
else
{
   push @attributes, 'quota', 'fquota', 'mboxacl' ;
   $mesg = $oss->{LDAP}->search( base   => $base,
                          scope  => $scope,
                          filter => $filter,
                          attrs  => $oss->{DEFAULT_GROUP_ATTRIBUTES}
                        );
}

if( ! $mesg )
{
        print STDERR "ERROR Could not search for the group\n";
        exit 1;
}
my $result = $mesg->as_struct;
foreach $dn ( keys %{$result} )
{
	if( contains( 'quota', \@attributes ) )
	{
	  my($q_val,$q_used) = $oss->get_quota_group($dn);
	  push @{$result->{$dn}->{quota}},"$q_val";
	  push @{$result->{$dn}->{quotaused}},"$q_used";
	}

	if( contains( 'fquota', \@attributes ) )
	{
	  my($q_val,$q_used) = $oss->get_fquota_group($dn);
	  push @{$result->{$dn}->{fquota}},"$q_val";
	  push @{$result->{$dn}->{fquotaused}},"$q_used";
	}
	if( contains( 'mboxacl', \@attributes ) )
	{
	  my $acls = $oss->get_mbox_acl($dn);
	  foreach my $owner ( keys %{$acls} )
	  {
	    push @{$result->{$dn}->{mboxacl}},"$owner ".$acls->{$owner};
	  }
	}
}
print $oss->reply($result);

