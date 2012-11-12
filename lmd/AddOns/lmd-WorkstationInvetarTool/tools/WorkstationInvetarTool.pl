#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

use strict;
use oss_base;
use oss_utils;
use DBI;
use DBI qw(:utils);

use vars qw(@ISA);
@ISA = qw(oss_base);
use Data::Dumper;

my $oss    = oss_base->new();
my $rooms = $oss->get_rooms('all');

foreach my $dnroom (keys %{$rooms})
{
        foreach my $dn ( @{$oss->get_workstations_of_room($dnroom)} )
        {
                my $hostname = $oss->get_attribute($dn,'cn');
                my @pchwinfo = ('bios', 'cdrom', 'chipcard', 'cpu', 'disk', 'gfxcard', 'keyboard', 'memory', 'monitor', 'mouse', 'netcard', 'printer', 'sound', 'storage-ctrl');

                for(my $i=0; $i< scalar(@pchwinfo); $i++){
                        my $file = '/srv/itool/hwinfo/'.$hostname.'/'.$pchwinfo[$i];
                        if( open(FILE,"< $file") ){
				my (@hardwareclass, @model, @vendor,@device,@configstatus) = ();
                                while(<FILE>){
                                        my $row = trim($_);
					if($row =~ /^Model:/){
						@model = split(': ',$row);
                                                $oss->create_vendor_object($dn,'hwinfo',"$pchwinfo[$i]".'_model',$model[1]);
                                        }elsif($row =~ /^Vendor:/){
						@vendor = split(': ',$row);
                                                $oss->create_vendor_object($dn,'hwinfo',"$pchwinfo[$i]".'_vendor',$vendor[1]);
                                        }elsif($row =~ /^Device:/){
						@device = split(': ',$row);
                                                $oss->create_vendor_object($dn,'hwinfo',"$pchwinfo[$i]".'_device',$device[1]);
                                        }
                                }
                                close (FILE);
                        }else{
                                print "Can\'t open $file !\n";
                                next;
                        }
                }
        }
}


foreach my $HW ( @{$oss->get_HW_configurations(0)}  )
{
	my $hwconfN = $oss->get_attributes( 'configurationKey='.$HW->[0].','.$oss->{SYSCONFIG}->{COMPUTERS_BASE},
                                            ['configurationvalue','description']
                                          );

	my $result = $oss->{LDAP}->search( base   => $oss->{SYSCONFIG}->{DHCP_BASE},
                                            scope   => 'sub',
                                            attrs  => [ 'dn' ],
                                            filter  => '(&(objectClass=SchoolWorkstation)(cn=*)(configurationValue=HW='.$HW->[0].'))'
	        );
        my @dnpc;
        foreach my $entry ( $result->entries() ){
                push @dnpc, $entry->dn();
        }
	
	foreach my $dn (@dnpc){
		my $value = $oss->get_vendor_object($dn,'hwinfo','warranty');
	        if($value->[0]){
	        }else{
			$oss->create_vendor_object($dn,'hwinfo','warranty',"$hwconfN->{configurationvalue}->[2]");
	        }
	}
}


sub trim($)
{
        my $string = shift;
        $string =~ s/^\s+//;
        $string =~ s/\s+$//;
        return $string;
}
