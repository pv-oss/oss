#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2005 Peter Varkoly Fuerth, Germany.  All rights reserved
# <peter@varkoly.de>

BEGIN{
    push @INC,"/usr/share/oss/lib";
}

$| = 1; # do not buffer stdout

use strict;
use Net::LDAP;
use oss_base;

my $time = shift || `date  +%H:%M`;
chomp $time;

my $oss = oss_base->new || exit;

my $result = $oss->{LDAP}->search(
		base   => 'ou=DHCP,'.$oss->{LDAP_BASE},
		filter => "serviceAccesControl=$time*",
		attr   => ['serviceAccesControl','dhcpRange','dhcpNetMask','description'] 
	);

foreach my $entry ($result->all_entries) {
	my $network= $entry->get_value('dhcpRange').'/'.$entry->get_value('dhcpNetMask');
	my $desc   = $entry->get_value('description');
	my @DSAC   = ();
        my @SAC    = ();
	foreach my $access ($entry->get_value('serviceAccesControl')){
	    my @defaults = split / /,$access;
	    my $tmp      = shift @defaults;
	    if($tmp eq 'DEFAULT')  {
		@DSAC = @defaults;
		if($time eq 'DEFAULT' ) {
		    @SAC = @DSAC;
		    last;
		}
	    } elsif ($tmp eq $time ) {
		@SAC = @defaults;
	    }
	}
        if($SAC[0] eq 'DEFAULT' ) {
	   @SAC = @DSAC;
	}
	foreach my $serv (@SAC) {
	    my ($s,$d) = split /:/,$serv;
	    if( defined $s && defined $d ) {
		if( $s eq 'ClientControl' )
		{
		    system("/usr/sbin/oss_control_room.pl --room $desc --cmd $d");
		}
		else
		{
		    system("/usr/sbin/oss_set_access_state $d $network $s");
		}
	    }
	}
}
$oss->destroy;
