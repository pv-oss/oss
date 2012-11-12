#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
#use Data::Dumper;
use oss_utils;

my $zones = get_time_zones();

print "<reply>\n";
print "  <default>$zones->{default}</default>\n";
print "  <zone-s>\n";

foreach my $zone (@{$zones->{zones}}) {
  print "    <zone>$zone</zone>\n";
}

print "  </zone-s>\n";
print "</reply>\n";
