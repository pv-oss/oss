#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
use strict;

my $time =shift;
my @T=localtime($time); 
printf("%4d-%02d-%02d %02d:%02d\n", $T[5]+1900,$T[4]+1,$T[3],$T[2],$T[1]);
