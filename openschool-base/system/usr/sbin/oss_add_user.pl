#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_user;
use oss_utils;
binmode STDIN, ':utf8';
if( $> )
{
    die "Only root may start this programm!\n";
}

my $USER =  {};
my $connect  = { withIMAP => 1 }; 

while(my $param = shift)
{
    if( $param =~ /text/i ) { $connect->{XML}=0; }
}

while(<STDIN>)
{
    # Clean up the line!
    chomp; s/^\s+//; s/\s+$//;
    
    my ( $key, $value ) = split / /,$_,2;
    
    next if( getConnect($connect,$key,$value));

    if( $key =~ /^(class|group|mail)$/ )
    {
           push @{$USER->{$key}}, $value;
    }
    elsif( $key eq "userpassword_repeated" )
    {
    	next;
    }
    elsif( defined $value)
    {
    	$USER->{$key} = $value;
    }
    else
    {
    	$USER->{$key} = 1;
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

my $oss_user = oss_user->new($connect);
my $DEBUG               = 0;
if( $oss_user->get_school_config('SCHOOL_DEBUG') eq 'yes' )
{
  $DEBUG = 1;
  use Data::Dumper;
}

if( ! $oss_user->add($USER) )
{
  print Dumper($USER) if($DEBUG);
  die $oss_user->{ERROR}->{text};
}

if( $DEBUG )
{
	open(OUT,">/tmp/add_user.".$USER->{uid});
	print OUT Dumper($USER);
	close OUT;
}

print $oss_user->replydn($USER->{dn});
$oss_user->destroy();
