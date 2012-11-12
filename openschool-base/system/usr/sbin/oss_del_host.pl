#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_host;
use oss_utils;
binmode STDIN, ':utf8';
if( $> )
{
    die "Only root may start this programm!\n";
}

my @dns     = ();
my $connect  = { withIMAP => 1 };
my $oss_host = undef;

while(my $param = shift)
{
    if( $param =~ /text/i ) { $connect->{XML}=0; }
}


while(<STDIN>){
    # Clean up the line!
    chomp; s/^\s+//; s/\s+$//;

    my ( $key, $value ) = split / /,$_,2;
    
    next if( getConnect($connect,$key,$value));

    if( $_ ne '' )
    {
      push @dns, $_;
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

foreach my $dn ( @dns )
{
    $oss_host->delete($dn);
}
