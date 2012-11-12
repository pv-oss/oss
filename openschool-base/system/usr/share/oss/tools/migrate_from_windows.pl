#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib"
}

use strict;
use Data::Dumper;
use Net::LDAP;
use Getopt::Long;
use oss_base;
use oss_utils;

# Global Variables
my ($mesg, $result, $password, $server ) = "";
my $user       = "Administrator";
my $todo       = "groups";
my %options    = ();
my $oss        = oss_base->new();

sub usage
{
	print   'Usage: /usr/share/oss/tools/migrate_from_windows.pl [OPTION]'."\n".
		'Leiras .....'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		'	     --password      Adminpassword.'."\n".
		'	     --I             Server IP.'."\n".
		'	     --S             Servers name.'."\n".
		'	     --get           groups|users Default "groups".'."\n".
		'	     --user          Adminuser Default "Administrator".'."\n".
		'Optional parameters: '."\n".
		'	-h,  --help          Display this help.'."\n".
		'	-d,  --description   Display the descriptiont.'."\n";
}

sub get_groups
{
  my $wgroups   = {};
  my $newgroup  = 0;
  open (NEWGROUPS,">NEWGROUPS");
  print NEWGROUPS "Display name:name:type\n";

  my $groups    = {};
  foreach my $dn ($oss->get_school_groups('*'))
  {
    my $disp = lc($oss->get_attribute($dn,'displayName'));
    $groups->{$disp} = get_name_of_dn($dn);
  }

  my @wg = `net GROUP -U $user\%$password $server`;
  foreach my $wg ( @wg )
  {
    chomp $wg;
    print "Windows Group: $wg ";
    my $wgroup = lc($wg);
    if( defined $groups->{$wgroup} )
    {
      print "is defined as ".$groups->{$wgroup}." in the system\n";
    }
    else
    {
      print "have to be created\n";
      $wgroup =~ s/\s+//g;
      print NEWGROUPS "$wg:$wgroup:workgroup\n";
      $newgroup = 1;
    }
  }
  if( $newgroup )
  {
     print "###### WARNING ##### ACHTUNG #### FIGYELEM ###### WARNING ####\n";
     print "There was find groups which do not exists in our system.\n";
     print "Pleas edit the file \"NEWGROUPS\" befor you start the migration of the users!\n";
  }
}

sub get_users
{
  if ( ! -e "NEWGROUPS" )
  {
    print "\nFirst you have to migrate the groups! Please start this program with the option \"--get groups\"\n\n"; 
    exit 1;
  }
  #Reading the new groups file
  my @NEWGROUPS = split /\n/,get_file("NEWGROUPS");

  #Skipping header
  shift @NEWGROUPS;
  
  #Creating all new groups
  foreach( @NEWGROUPS )
  {
    my( $disp, $cn, $type ) = split /:/;
    my $args = "cn $cn\ndisplayname $disp\ngrouptype $type";
    if( $type eq 'primary' )
    {
      $args .= "\nrole $cn";
    }
    my $out = cmd_pipe("/usr/sbin/oss_add_group.pl",$args);
    print $out."\n############### $disp done ###############\n\n";
  }
  #Create group hash
  my $groups    = {};
  foreach my $dn ($oss->get_school_groups('*'))
  {
    my $disp = lc($oss->get_attribute($dn,'displayName'));
    $groups->{$disp} = get_name_of_dn($dn);
  }

  my @wus = `net RPC USER -U $user\%$password $server`;
  foreach my $wu ( @wus )
  {
     chomp $wu; 
     my @wug  = `net RPC USER INFO $wu -U $user\%$password $server`;
     my $prim = shift @wug;
     chomp $prim;
     my $role = $groups->{lc($prim)};
     my $args = "uid $wu\ngivenname $wu\nsn $wu\nuserpassword $wu\nbirthday 1970-01-01\nrole $role\nreqpwdchange yes";
     foreach my $g ( @wug )
     {
       chomp $g;
       $args .= "\ngroup ".$groups->{lc($g)};
     }
     print $args."\n";
     my $out = cmd_pipe("/usr/sbin/oss_add_user.pl",$args);
     print $out."\n############### $wu done ###############\n\n";
  }

}

# MAIN
# First we get the arguments
$result = GetOptions(\%options,
                        "password=s",
                        "I=s",
                        "S=s",
                        "get=s",
                        "user=s",
			"description",
                        "help"
                        );
if (!$result && ($#ARGV != -1))
{
      usage();
      exit 1;
}
if ( defined($options{'help'}) )
{
        usage();
        exit 0;
}
if( defined($options{'description'}) )
{
	print   'NAME:'."\n".
		'	migrate_from_windows.pl'."\n".
		'DESCRIPTION:'."\n".
		'	Leiras ....'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		'		     --password      : Adminpassword.(type=string)'."\n".
		'		     --I             : Server IP.(type=string)'."\n".
		'		     --S             : Server name.(type=string)'."\n".
		'		     --get           : groups|users Default "groups.(type=string)'."\n".
		'		     --user          : Adminuser Default "Administrator".(type=string)'."\n".
		'	OPTIONAL:'."\n".
		'		-h,  --help          : Display this help.(type=boolean)'."\n".
		'		-d,  --description   : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}
if ( defined($options{'password'}) )
{
        $password=$options{'password'};
}
else
{
	print "\nYou have to define the administrator's passwort!\n!";
	usage();
	exit 1;
}
if ( defined($options{'I'}) )
{
        $server="-I ".$options{'I'};
}
if ( defined($options{'S'}) )
{
        $server="-S ".$options{'S'};
}
if ( $server eq '' )
{
	print "\nYou have to specify either the IP address or the name of a server!\n";
	usage();
	exit 1;
}
if ( defined($options{'user'}) )
{
        $user=$options{'user'};
}
if ( defined($options{'get'}) )
{
        $todo=$options{'get'};
}

if( $todo eq "groups" )
{
  get_groups();
}
if( $todo eq "users" )
{
  get_users();
}
