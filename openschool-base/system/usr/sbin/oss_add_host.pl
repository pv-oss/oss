#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_host;
use oss_utils;

if( $> )
{
    die "Only root may start this programm!\n";
}

my $HOST     = {};
my $connect  = {};
my $oss_host = undef;

while(my $param = shift)
{
  if( $param =~ /text/i ) { $connect->{XML}=0; }
}
binmode STDIN, ':utf8';
while(<STDIN>)
{
	# Clean up the line!
	chomp; s/^\s+//; s/\s+$//;

	my ( $key, $value ) = split / /,$_,2;

	next if( getConnect($connect,$key,$value)); 
        if( defined $key && defined $value ) 
	{
		$HOST->{$key}   = $value;
	}
}

# Make OSS Connection
if( defined $ENV{SUDO_USER} )
{
   if( ! defined $connect->{aDN} || ! defined $connect->{aPW} )
   {
       die "Using sudo you have to define the parameters aDN and aPW\n";
   }
}
$oss_host = oss_host->new($connect);

my $DEBUG               = 0;
if( $oss_host->get_school_config('SCHOOL_DEBUG') eq 'yes' )
{
  $DEBUG = 1;
  use Data::Dumper;
}

if( ! $oss_host->add($HOST) )
{
  print Dumper($HOST);
  die $oss_host->{ERROR}->{text};
}
if( $DEBUG )
{
	open(OUT,">/tmp/add_host.".$HOST->{uid});
	print OUT Dumper($HOST);
	close OUT;
}

my $dn = $HOST->{dn};

print $oss_host->replydn($dn);
$oss_host->destroy();
