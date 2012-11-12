#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

package SystemMonitor;

use strict;
use oss_base;
use vars qw(@ISA);
@ISA = qw(oss_base);

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    my $self    = oss_base->new($connect);
    return bless $self, $this;
}

sub interface()
{
  return  [ 'getCapabilities', 'default' ];
}

sub getCapabilities()
{
	return [
		{ title => 'System Monitoring Tools'},
		{ allowedRole => 'root'},
		{ allowedRole => 'sysadmins'},
		{ allowedRole => 'teachers,sysadmins'},
		{ category => 'System'},
		{ order => 60 }
	];
}

sub default()
{
	return [
		{ notranslate_label => '<a href="/nagios/cgi-bin/status.cgi?host=all" target="_blank">'.main::__('State of Services').'</a>' },
		{ notranslate_label => '<a href="/nagios" target="_blank">'.main::__('Nagios').'</a>' },
		{ notranslate_label => '<a href="https://printserver:631/" target="_blank">'.main::__('Printserver').'</a>' }
	];
}

1;
