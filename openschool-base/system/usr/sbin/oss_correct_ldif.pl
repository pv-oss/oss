#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

use oss_utils;

my $file = shift;

my $ldif = get_file($file);

$ldif =~ s/\n //g;

print $ldif;
