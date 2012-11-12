#!/usr/bin/perl  -w
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# (c) 2011 EXTIS GmbH
# Revision: $Rev: 1618 $

BEGIN{
    push @INC,"/usr/share/oss/lib/"
}
use strict;
use oss_base;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
			"nr_rooms=s",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/add_room_net.pl [OPTION]'."\n".
		'With this script we can create new rooms to the network (free rooms). (The more networking rooms we create the more classrooms we can assign from the OSSadmin platform.)'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		'	     --nr_rooms     Number of rooms.'."\n".
		'Optional parameters : '."\n".
		'	-h,  --help         Display this help.'."\n".
		'	-d,  --description  Display the descriptiont.'."\n";
}

if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	add_room_net.pl'."\n".
		'DESCRIPTION:'."\n".
		'	With this script we can create new rooms to the network (free rooms). (The more networking rooms we create the more classrooms we can assign from the OSSadmin platform.)'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		'		     --nr_rooms    : Number of rooms.(type=string)'."\n".
		'	OPTIONAL:'."\n".
		'		-h,  --help        : Display this help.(type=boolean)'."\n".
		'		-d,  --description : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}
my $rooms = undef;
if( defined($options{'nr_rooms'}) ){
	$rooms = $options{'nr_rooms'};
}else{
	usage(); exit 0;
}

# Get hostname
my $host = `hostname -s`;
chomp $host;

# Read some values from rcconfig
my $oss   = oss_base->new();

my $netmask      = $oss->get_school_config("SCHOOL_NETMASK");
my $network      = $oss->get_school_config("SCHOOL_NETWORK");
my $first_net    = $oss->get_school_config("SCHOOL_FIRST_ROOM_NET");
my $room_nr      = $oss->get_school_config("SCHOOL_ROOM_NR");
$rooms += $room_nr;
$netmask   =~ /(\d+)\.(\d+).(\d+).(\d+)/;
my $duesseldorf = 0;
if( $3 eq '255' )
{
   $duesseldorf = 1;
}

$first_net =~ /(\d+)\.(\d+).(\d+).(\d+)/;

my $A  = $1;
my $B  = $2;
my $C  = $3;
my $D  = $4;
if($duesseldorf)
{
  $B += int($room_nr/4);
}
else
{
  $C += int($room_nr/4);
}
$D += ($room_nr%4) * 64;

print "First new Room Network: $A.$B.$C.$D\n";
for (my $i=$room_nr; $i < $rooms; $i++)
{
  print "Room$i: $A.$B.$C.$D\n"; 
  $oss->{LDAP}->add( dn => "cn=Room$i,cn=$network,cn=config1,cn=$host,ou=DHCP,".$oss->{LDAP_BASE},
            attr => [
	    		objectClass => [ 'top','dhcpOptions','dhcpGroup','SchoolRoom' ],
			cn          => "Room$i",
			dhcpNetMask => 26,
			dhcpRange   => "$A.$B.$C.$D"
	            ]
		);
      $D = $D + 64;
      if( $D > 255)
      {
         $D = 0;
         if($duesseldorf)
	 {
	   $B += 1;
           if( $B > 255 )
	   {
	      print "Not enough network space for $rooms.\n";
	      print "You have $i rooms actually.\n";
	      $rooms = $i;
	      last;
           }
	 }
	 else
	 {
           $C += 1;
           if( $C > 255 )
	   {
             $C = 0;
             $B += 1;
           }
	 }
      }
}
$oss->{LDAP}->modify( "configurationKey=SCHOOL_ROOM_NR,ou=sysconfig,".$oss->{LDAP_BASE},
                replace => { configurationValue => $rooms }
		             );
$oss->destroy;

system("sed -i 's/^SCHOOL_ROOM_NR=.*/SCHOOL_ROOM_NR=\"$rooms\"/' /etc/sysconfig/schoolserver");
