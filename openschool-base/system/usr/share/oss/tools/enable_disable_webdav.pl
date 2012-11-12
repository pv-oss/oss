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
use oss_base;

# Global variable
my %options    = ();
my $result     = "";
my $group      = undef;
my $member     = 0;
my $enable     = undef;

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
    
    if ( $key eq "group" )
    {
      $group = $value;  
    }
    elsif ( $key eq "member" )
    {
      $member = 1;  
    }
    elsif ( $key eq "enable" )
    {
      $enable = 1;  
    }
    elsif ( $key eq "disable" )
    {
      $enable = 0;  
    }
  }
  
}
else
{
  # Parsing the attributes
  $result = GetOptions(\%options,
  			"help",
  			"group=s",
  			"member",
			"enable",
			"disable"
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
  if ( defined($options{'group'}) ) 
  {
  	$group=$options{'group'};
  }
  if ( defined($options{'member'}) ) 
  {
  	$member=1;
  }
  if ( defined($options{'enable'}) ) 
  {
  	$enable=1;
  }
  if ( defined($options{'disable'}) ) 
  {
  	$enable=0;
  }
}

if( !defined $group && !defined $enable )
{
  usage();
  exit 0;
}

##############################################################################
## Print the option usage
sub usage
{

        print "enable_disable_webdav.pl --group <group> --enable | --disable [ --member ] \n";
        print "Options:\n";
        print "  --help         Print this help message\n";
        print "  --group        The concerned group. This may be 'all'. Template and workstation groups will be ignored.\n";
        print "  --member       If given the script is tratint not the group but its member\n";
        print "  --enable\n";
	print "  --disable      enable or disable webdav.\n";
	print "Otherwise you can pipe the attributes on STDIN (it is safer). In this case use '-' as option:\n\n";
        print "echo \"group teachers\n";
	print "member\n";
	print "enable\" | enable_disable_webdav.pl -\n\n";
}
my @groups = ();
my @DNs    = ();
my $oss = oss_base->new();
if( ! $oss )
{
  print $oss->{ERROR}->{text};
  exit 1;
}
if( $group eq 'all' )
{
	foreach my $g ( @{$oss->get_school_groups('*')} )
	{
		next if ( $oss->is_template($g) );
		next if ( $oss->is_workstation($g) );
		push @groups, $g;
	}
}
else
{
	push @groups, $oss->get_group_dn($group);
}
$oss->destroy;

if($member)
{
	use oss_user;
	$oss = oss_user->new();
	if( ! $oss )
	{
	  print $oss->{ERROR}->{text};
	  exit 1;
	}
	foreach my $g ( @groups )
	{
		foreach my $dn ( @{$oss->get_users_of_group($g)})
		{
			next if ( $dn =~ /^cn=Administrator/ );
			push @DNs, $dn;
		}
	}
}
else
{
	use oss_group;
	$oss = oss_group->new();
	if( ! $oss )
	{
	  print $oss->{ERROR}->{text};
	  exit 1;
	}
	foreach my $g ( @groups )
	{
		push @DNs, $g;
	}
}

foreach my $dn (@DNs)
{
	print "Processing $dn\n";
	if($member){
		$oss->make_delete_user_webdavshare($dn,$enable);
	}else{
		$oss->make_delete_group_webdavshare($dn,$enable);
	}
}
$oss->destroy;
