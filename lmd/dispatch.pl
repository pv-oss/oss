#!/usr/bin/perl
#
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# dispatch.pl
#

BEGIN{ push @INC,"/usr/share/lmd/"; }

$| = 1; # do not buffer stdout

use strict;
use dispatch;

use CGI;
use CGI qw(-no_xhtml);
use CGI::Carp qw(fatalsToBrowser);
use subs qw(exit);
# Select the correct exit function
*exit = $ENV{MOD_PERL} ? \&Apache::exit : sub { CORE::exit };

my $cgi=new CGI;

my $menu = new dispatch($cgi);
$menu->display();

