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
my $mesg	= undef;
my $dn          = '';
my $IP          = '';
my $MAC         = '';
my $HOST_NAME   = '';

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
	if( $key ne '' )
	{
		$dn = $key;
	}
  }
  elsif ( $key =~ /IP/i )
  {
	$IP = $value;
  }
  elsif ( $key =~ /MAC/i )
  {
	$MAC = $value;
  }
  elsif ( $key =~ /HOST_NAME/i )
  {
	$HOST_NAME = $value;
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


#-----------------------------------------------------------------------------
if( $IP eq '' && $MAC eq '' && $HOST_NAME eq '' )
{
  print $oss->reply($oss->get_rooms);
}
elsif( $IP ne '' )
{
  print $oss->reply($oss->get_room_of_ip($IP,1));
}
exit;
