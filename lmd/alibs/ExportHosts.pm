# DYN-DNS modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ExportHosts;

use strict;
use oss_base;
use oss_utils;
use MIME::Base64;
use Data::Dumper;
use vars qw(@ISA);
@ISA = qw(oss_base);


sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    my $self    = oss_base->new($connect);
    return bless $self, $this;
}

sub interface
{
        return [
                "getCapabilities",
                "default",
		"exportHosts",
        ];

}

sub getCapabilities
{
        return [
                { title        => 'ExportHosts' },
                { type         => 'command' },
                { allowedRole  => 'root' },
                { allowedRole  => 'sysadmins' },
                { category     => 'Network' },
                { order        => 90 },
		{ variable     => [ "export_all",      [ type => "boolean" ] ] },
		{ variable     => [ "Rembo",           [ type => "boolean" ] ] },
		{ variable     => [ "export_rooms",    [ type => "list", size=>"15", multiple=>"true" ] ] }
        ];
}

sub default
{
	my $this  = shift;
	my $reply = shift;
	my @ret;
	my $rooms = $this->get_rooms('all');
	my @rooms;

	if($reply->{warning}){
		push @ret, {NOTICE => "$reply->{warning}"};
	}

	foreach my $dn (keys %{$rooms})
	{
		next if ( $rooms->{$dn}->{"description"}->[0] eq 'ANON_DHCP' );
		push @rooms, [ $dn, $rooms->{$dn}->{"description"}->[0]];
	}

	push @ret, { label => "A. If you wish to export all the Rooms PC s then check it here:" };
	push @ret, { export_all => '' };
	push @ret, { label => "B. If you wish to export only a few PC s then select check those:" };
	push @ret, { export_rooms => \@rooms };
	push @ret, { Rembo       => 0 };
	push @ret, { rightaction => 'exportHosts'};
	push @ret, { rightaction => 'cancel'};

	return \@ret;
}

sub exportHosts
{
	my $this  = shift;
	my $reply = shift;
	my $hostlist = '';
	my %hash;
	my %rooms;

	#get school netmask
	my $school_netmask = $this->get_school_config("SCHOOL_NETMASK");

	if(!$reply->{Rembo})
	{
		$hostlist = "Room;PC Name;HW Configuration;MAC-Address;IP-Address;Inventory Number;Serial Number;Position\n";
	}

	if($reply->{export_all} and $reply->{export_rooms})
	{
		$reply->{warning} = main::__('Please select only A. to select everything or B chose the classrooms !');
		return $this->default($reply);
	}
	elsif($reply->{export_all})
	{
		my $tmp = $this->get_rooms('all');
		foreach my $dn (keys %{$tmp})
		{
			$rooms{$dn} = $tmp->{$dn}->{"description"}->[0];
		}
	}
	elsif($reply->{export_rooms})
	{
		my @dn_rooms = split('\n', $reply->{export_rooms});
		foreach my $dn_room (@dn_rooms){
			my $room_description = $this->get_attribute($dn_room,'description');
			$rooms{$dn_room} = $room_description;
		}
	}
	else
	{
		$reply->{warning} = main::__('Please check from A. everything or from B. select the rooms !');
		return $this->default($reply);
	}

	foreach my $dn (keys %rooms)
	{
		#get room name
		next if ( $rooms{$dn} eq 'ANON_DHCP' );
		my $room_name = $rooms{$dn};
		foreach my $dn ( @{$this->get_workstations_of_room($dn)} )
		{
			#get pc name
			my $pc_name = $this->get_attribute($dn,'cn');
			#get pc hardware configuration
			my $pc_hw_config = $this->get_config_value($dn,'HW');
			my @hwconf       = @{$this->get_HW_configurations(1)};
			my $pc_hw_config_description;
			foreach my $hwconfig (@hwconf)
			{
				if( $hwconfig->[0] eq $pc_hw_config )
				{
					$pc_hw_config_description = $hwconfig->[1];
					last;
				}
			}
			#get pc hardware address
			my $pc_hwaddress= $this->get_attribute($dn,'dhcpHWAddress');
			$pc_hwaddress =~ s/ethernet //i;
			#get pc ip address
			my $pc_ipaddress   = $this->get_attribute($dn,'dhcpStatements');
			$pc_ipaddress =~ s/fixed-address //i;
			if($reply->{Rembo})
			{
				$hash{$room_name}->{$pc_name} = "$pc_hw_config_description;$pc_hwaddress;$pc_ipaddress;$school_netmask;1;1;1;1;22;noprotpart\n";
			}
			else
			{
				my $inventary = $this->get_vendor_object($dn,'EXTIS','INVENTARNUMBER') ||'';
				my $serial    = $this->get_vendor_object($dn,'EXTIS','SERIALNUMBER') ||'';
				my $position  = $this->get_vendor_object($dn,'EXTIS','COORDINATES') ||'';
				$hash{$room_name}->{$pc_name} = "$pc_hw_config_description;$pc_hwaddress;$pc_ipaddress;$inventary;$serial;$position\n";
			}
		}
	}

	foreach my $room_name (sort keys %hash )
	{
		foreach my $host_name (sort keys %{$hash{$room_name}} )
		{
			$hostlist .= "$room_name;$host_name;$hash{$room_name}->{$host_name}";
		}
	}


	my( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst )   = localtime(time);
	my $file_name = "hostlist-".sprintf('%4d-%02d-%02d-%02d-%02d', $year+1900, $mon+1, $mday, $hour, $min).".txt";

	return [
		{name => 'download', value=>encode_base64($hostlist), attributes => [ type => 'download', filename=> "$file_name", mimetype=>'text/plain']}
	];

}

1;
