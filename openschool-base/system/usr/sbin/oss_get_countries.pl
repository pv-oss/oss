#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}
use strict;
use oss_utils;
use Config::IniFiles;
binmode STDIN, ':utf8';

my $LANG = 'DE';

while(<STDIN>)
{
  chomp;
  $LANG = $_;
}

my $ini = Config::IniFiles->new( -file => "/usr/share/oss/lib/country_codes.ini" );

my @LANGUAGES = $ini->Sections();

if( !contains($LANG,\@LANGUAGES))
{
  $LANG = 'EN';
}

print "<reply>\n";
foreach my $c ( $ini->Parameters($LANG) )
{
  my @values = $ini->val($LANG,$c);
  my $name   = substr $values[0], 0, 25;
  print '  <country name="'.$name.'">'.$c."</country>\n";
}
print "</reply>\n";
