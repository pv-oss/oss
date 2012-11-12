#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN
{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_base;

my $uid       = shift;
my $IP        = shift;
my $arch      = shift || '';

my $oss = oss_base->new();
my $dn = $oss->get_workstation($IP);
my $mac     = $oss->get_attribute($dn,'dhcpHWAddress');
$mac =~ s/ethernet //;
$mac =~ s/:/-/g;
$mac = "01-".lc($mac);
if ( -e "/srv/tftp/pxelinux.cfg/$mac" )
{
   unlink "/srv/tftp/pxelinux.cfg/$mac"
}
$oss->destroy;
