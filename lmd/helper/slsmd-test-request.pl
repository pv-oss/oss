#!/usr/bin/perl
#
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2007 Peter Varkoly <peter@varkoly.de>, Fürth.  All rights reserved.
#
# $Id: lmd.pl pv Exp $
#
#
=head1 NAME

 lmd-test-request.pl.pl
 
=head1 PREFACE

 SUSE Linux System Managemant Daemon Tester Program

=head1 DESCRIPTION

This Program sends som test request to lmd.

=cut

use strict;
use Getopt::Long;
use XML::Parser;
use Data::Dumper;
use IO::Socket::UNIX;
use IO::Socket::SSL;

my $CLIENT;
my $PORT        = "1967";
my $ADDRESS     = "127.0.0.1";
my $SOCKET      = "/var/run/lmd.sock";
my $DEBUG       = 1;

my $apps        = shift;
my $action      = shift || 'default';

my $REQUEST  = '<request name="getMenu" />' ;

if( $apps && $action )
{
   $REQUEST = '<request name="'.$action.'" application="'.$apps.'" />';
}
	 
#Parsing Command Line Parameter
my %options = ();
my $result  = GetOptions( \%options, "port=s", "debug", "help" );
if (!$result || $options{'help'})
{
      usage();
      exit 1;
}
if( defined $options{'port'} )
{
    $PORT = $options{'port'};
}
if( defined $options{'address'} )
{
    $ADDRESS = $options{'address'};
}
if ( defined($options{'debug'}) )
{
    $DEBUG = 1;
}

#start the socket
if( $ADDRESS eq "unix" )
{
    $CLIENT = IO::Socket::UNIX->new(
        Type           => SOCK_STREAM,
        Peer           => $SOCKET
    );
}
else
{   
    $CLIENT = IO::Socket::SSL->new(
        PeerAddr       => $ADDRESS,
        PeerPort       => $PORT,
        Proto          => 'tcp',
        Type            => SOCK_STREAM
    );
}

print $CLIENT length($REQUEST)."\n";
print $CLIENT $REQUEST;

my ($REPLY, $length);

while(<$CLIENT>)
{
    $length = $_;
    chomp $length;
    last;
}
$CLIENT->read($REPLY, $length);

print $REPLY;
# 
