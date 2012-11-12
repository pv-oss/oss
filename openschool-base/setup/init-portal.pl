#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly Nürnberg, Germany.  All rights reserved.

BEGIN { 
	push @INC,"/usr/share/lmd/alibs/"; 
}

use Portal;

my $portal = Portal->new();

sub __($)
{
	return shift;
}

$portal->create_page();
 
