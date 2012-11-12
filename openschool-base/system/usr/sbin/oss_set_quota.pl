#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2005 Peter Varkoly Fuerth, Germany.  All rights reserved.
#
# $Id: oss_set_quota.pl,v 1.4 2006/09/19 06:21:52 pv Exp $
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use Getopt::Long;
use Net::LDAP;
use oss_base;
use oss_utils;
binmode STDIN, ':utf8';
# Make LDAP Connection
my $oss = oss_base->new({withIMAP=>1});
if( ! $oss )
{
  print $oss->{ERROR}->{text};
  exit 1;
}

# Global variable
my %options    = ();
my $result     = "";
my $uid        = undef;
my $noteachers = 1;
my $group      = undef;
my $mquota     = undef;
my $fquota     = undef;

if( $#ARGV == 0 && $ARGV[0] eq '-' )
{
  # Reading the attributes from STDIN
  while(<STDIN>)
  {
    my ( $key, $value ) = split / /,$_,2;
    
    if ( defined $value )
    {
      chomp $value;
    }
    else
    {
      chomp $key;
    }
    
    if( $key eq "uid" ) {
      $uid = $value;  
    } 
    elsif ( $key eq "group" )
    {
      $group = $value;  
    }
    elsif ( $key eq "noteachers" )
    {
      $noteachers = 1;  
    }
    elsif ( $key eq "mquota" )
    {
      $mquota = $value;  
    }
    elsif ( $key eq "fquota" )
    {
      $fquota = $value;  
    }
  }
  
}
else
{
  # Parsing the attributes
  $result = GetOptions(\%options,
  			"help",
  			"group=s",
  			"uid=s",
  			"noteacher=s",
  			"fquota=s",
  			"mquota=s"
  			);
  
  if (!$result && ($#ARGV != -1))
  {
  	usage();
  	exit 1;
  }
  if ( defined($options{'help'}) ) {
  	usage();
  	exit 0;
  }
  if ( defined($options{'noteachers'}) ) 
  {
  	$noteachers=$options{'noteachers'};
  }
  if ( defined($options{'group'}) ) 
  {
  	$group=$options{'group'};
  }
  if ( defined($options{'uid'}) ) 
  {
  	$uid=$options{'uid'};
  }
  if ( defined($options{'mquota'}) )
  {
  	$mquota=$options{'mquota'};
  }
  if ( defined($options{'fquota'}) )
  {
  	$fquota=$options{'fquota'};
  }
}

if( !defined $uid && !defined $group )
{
  usage();
  exit 0;
}
if( !defined $mquota && !defined $fquota )
{
  usage();
  exit 0;
}

if( $group eq 'teachers' )
{
  $noteachers = 0;
}

##############################################################################
## Print the option usage
sub usage
{

        print "oss_set_quota.pl --group <group> --uid <uid> --fquota <file system quota in MB> --mquota <mailbox quota in MB>\n";
        print "Options:\n";
        print "  --help         print this help message\n";
        print "  --group        the group which users are concerned\n";
        print "  --noteachers   the changes do not concer the teachers. Default value is 1\n";
        print "  --uid          the concerned user\n";
        print "  --fquota       file system quota in MB\n";
        print "  --mquota       mailbox quota in MB\n";
	print "Otherwise you can pipe the attributes on STDIN (it is safer). In this case use '-' as option:\n\n";
        print "echo \"uid bigboss\n";
	print "mquota 100\" | oss_set_user_quota.pl -\n\n";
}

my @DNs  = ();

if( $uid )
{
  push @DNs, $oss->get_user_dn($uid);  
}

if($group)
{
	foreach my $dn ( @{$oss->get_users_of_group($oss->get_group_dn($group))})
	{
	  if( $noteachers )
	  {
	    next if ( $oss->is_teacher($dn) );
	  }
          push @DNs, $dn;
	}
}


foreach my $dn (@DNs)
{
  if( defined $fquota )
  {
    print "Setting file system quota for $dn to $fquota MB\n";
    $oss->set_fquota($dn,$fquota);
  }
  if( defined $mquota )
  {
    print "Setting mailbox quota for $dn to $mquota MB\n";
    $oss->set_quota($dn,$mquota);
  }
}

