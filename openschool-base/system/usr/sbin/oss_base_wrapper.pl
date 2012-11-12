#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

BEGIN
{
        push @INC,"/usr/share/oss/lib/";
}
use oss_base;
use Data::Dumper;

my $what = shift;
my @A = ();
while(<>)
{
	chomp;
        push @A,$_
}
my $oss = oss_base->new();

my $a = $oss->$what(@A);
if( ref $a )
{
	print Dumper($a);
}
$oss->destroy;
