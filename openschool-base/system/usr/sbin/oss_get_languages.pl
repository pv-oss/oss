#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}
use strict;

my @LANGUAGES = ('DE','EN','HU','RO','IT','ES');

print "<reply>\n";
foreach my $c ( @LANGUAGES ){
  print '  <language>'.$c."</language>\n";
}
print "</reply>\n";
