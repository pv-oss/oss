# OSS BootConfiguration Module

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package BootConfiguration;

use strict;
use oss_base;
use Data::Dumper;
use oss_utils;
use Config::IniFiles;

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
		"edit",
		"save",
		"set",
        ];
}

sub getCapabilities
{
        return [
                { title        => 'BootConfiguration' },
                { type         => 'command' },
                { allowedRole  => 'root' },
                { allowedRole  => 'sysadmins' },
                { allowedRole  => 'teachers,sysadmins' },
                { category     => 'Network' },
                { order        => 40 },
		{ variable     => [ 'room',                  [ type => 'list', size =>'5', multiple => 'true' ], label => main::__('room') ]},
		{ variable     => [ 'edit',                  [ type => 'action' ] ]},
		{ variable     => [ "set",                   [ type => "action" ] ] },
		{ variable     => [ 'workstation',           [ type => 'label', style => "width:100px" ] ] },
		{ variable     => [ 'wstype',                [ type => 'label', style => "width:100px" ] ] },
		{ variable     => [ 'bootconfiguration',     [ type => 'popup' ]]  },
		{ variable     => [ 'room_dn',               [ type => 'hidden' ]]  },
		{ variable     => [ 'room_name',             [ type => 'label', style => "width:100px", label => main::__('room') ] ] },
	]
}

sub default
{
        my $this = shift;
        my $reply =shift;
	my @lines       = ('rooms');
        my $tmp         = $this->get_rooms('all');
        my %rooms       = ();

	my @table       = ('room',{ head => [ 'room', 'edit' ] } );
        foreach my $dn (sort keys %{$tmp})
        {
                $rooms{$tmp->{$dn}->{"description"}->[0]} = $dn;
		push @table, { line => [ $dn,
                                        { name => 'room_list', value  => $tmp->{$dn}->{"description"}->[0], attributes => [ type => 'label', style => "width:150px" ] },
                                        { edit => main::__('edit') },
                        ]};
        }

	my @r = ();
        push @r, { table    => \@table };
        push @r, { action   => 'cancel' };

        return \@r;	

}

sub edit
{
	my $this  = shift;
	my $reply = shift;
        my @lines       = ('ws');
	my @room_bootconf = ('room_bootconf');
	my @terminalservers = ();
        my $description = $this->get_attribute($reply->{line},'description');
	my $tmp         = $this->get_rooms('all');

	push @lines, { head => [ 'description', 'WSType', 'BootConfiguration' ] };
	push @room_bootconf, { head => [ 'room', 'WSType', 'BootConfiguration', '' ] };

	foreach my $dn_room (sort keys %{$tmp})
	{
		foreach my $dn_ws (sort @{$this->get_workstations_of_room($dn_room)} ) {
	                my @ws_hwconf = $this->get_attribute($dn_ws,'configurationValue');
			my $ws_hwconf_tmp;
			foreach my $conf_value (@ws_hwconf){
				if( $conf_value =~ /^HW=(.*)$/){
					$ws_hwconf_tmp = $1
				}
			}
	                my $ipaddress = $this->get_attribute($dn_ws,'dhcpStatements');
	                $ipaddress =~ s/fixed-address //i;
			my $hostname = $this->get_attribute($dn_ws,'cn');

			my $WSType = $this->get_computer_config_value('WSType',$ws_hwconf_tmp);
	                if($WSType eq 'LinuxTerminalServer' )
			{
				push @terminalservers, "LTS/$hostname/$ipaddress";
	                }
			elsif($WSType eq 'WindowsTerminalServer')
			{
                                push @terminalservers, "WTS/$hostname/$ipaddress";
                        }
	        }
	}

	my $msg_text = '';
        foreach my $dn_ws (sort @{$this->get_workstations_of_room($reply->{line})} ) {
		my $hostname = $this->get_attribute($dn_ws,'cn');
		my $wstype;
		my @BootConfig;
		my $ws_hwconf_tmp = $this->get_config_value($dn_ws,'HW');

		my @tomb = $this->get_ws_or_room_type($dn_ws,$ws_hwconf_tmp,@terminalservers);
		if($tomb[0]->{bootconfig} eq 'ws_or_room_type'){
			$msg_text .= "$hostname ,";
			push @lines, { line => [ $dn_ws,
                                       { workstation => $hostname },
                                       { wstype => $tomb[0]->{ws_or_room_type} },
                                       { name => 'bootconfiguration', value => '', attributes => [ type => 'label']},
                             ]};
		}else{
			push @lines, { line => [ $dn_ws,
                                       { workstation => $hostname },
                                       { wstype => $tomb[0]->{ws_or_room_type} },
                                       { bootconfiguration => $tomb[0]->{bootconfig} },
                             ]};
		}
	}

	my $room_HW = "";
	my @room_tmp = $this->get_attribute($reply->{line},'configurationValue');
        foreach my $room_ (@room_tmp){
                if( $room_ =~ /^HW=(.*)$/){
			$room_HW = $1;
		}
	}

	my @ret;
	if($room_HW and ($room_HW ne '-')){
		my @tomb = $this->get_ws_or_room_type($reply->{line},$room_HW,@terminalservers);
		push @room_bootconf, { line => [ $reply->{line},
					       { room_name => $description},
	                                       { wstype => $tomb[0]->{ws_or_room_type}},
	                                       { bootconfiguration => $tomb[0]->{bootconfig}},
					       { set => main::__('apply')},
					       { name => 'room_HW', value => "$room_HW", attributes => [ type => 'hidden']},
	                        ]};
		if($msg_text ne ''){
			 push @ret, { NOTICE => main::__('The following computers don\'t have hardware configs set : ').$msg_text};
		}

		push @ret, { subtitle => $description };
		push @ret, { label => 'Select the configuration for entire room.'};
		push @ret, { table    => \@room_bootconf};
		push @ret, { label => 'Select the configuration for a single workstation.'};
		push @ret, { table    =>  \@lines };
		push @ret, { room_dn => $reply->{line}};
		push @ret, { action   => "cancel" };
		push @ret, { action   => "save" };
		return \@ret;
	}else{
		if($lines[2] eq undef){
			return
	                [
	                   { subtitle => $description },
			   { NOTICE => main::__('There isn\'t a hardware configuration set for the classroom and there aren\'t any computers in the classroom!')},
	                   { action   => "cancel" },
	                ];
		}else{
			if($msg_text ne ''){ 
	                        push @ret, { NOTICE => main::__('The following computers don\'t have hardware configs set : ').$msg_text};
	                }
			push @ret, { subtitle => $description };
			push @ret, { NOTICE => main::__('There isn\'t a hardware configuration set for the classroom!') };
	                push @ret, { label => 'Select the configuration for a single workstation.'};
	                push @ret, { table    =>  \@lines };
	                push @ret, { room_dn => $reply->{line}};
	                push @ret, { action   => "cancel" };
	                push @ret, { action   => "save" };
	                return \@ret;
		}
	}

}

sub set
{
	my $this  = shift;
        my $reply = shift;

	# create WorkstationType in ldap
        $this->delete_vendor_object($reply->{line},'EXTIS','BootConfiguration');
        $this->create_vendor_object( $reply->{line}, 'EXTIS','BootConfiguration', $reply->{room_bootconf}->{$reply->{line}}->{bootconfiguration});

	foreach my $dn ( @{$this->get_workstations_of_room($reply->{line})} ) {
                my $ws_hw = $this->get_config_value($dn,'HW');
		if($ws_hw eq $reply->{room_bootconf}->{$reply->{line}}->{room_HW}){
			# create WorkstationType in ldap
	                $this->delete_vendor_object($dn,'EXTIS','BootConfiguration');
	                $this->create_vendor_object( $dn, 'EXTIS','BootConfiguration', $reply->{room_bootconf}->{$reply->{line}}->{bootconfiguration});

	                #create boot files and lts.conf files
	                $this->create_boot_file($reply->{room_bootconf}->{$reply->{line}}->{bootconfiguration}, $dn);
		}
	}
	return { TYPE => 'NOTICE', MESSAGE => 'pxe_written'};
}

sub save
{
	my $this  = shift;
	my $reply = shift;

	foreach my $dn ( @{$this->get_workstations_of_room($reply->{room_dn})} ) {
		 # create WorkstationType in ldap
                 $this->delete_vendor_object($dn,'EXTIS','BootConfiguration');
                 $this->create_vendor_object( $dn, 'EXTIS','BootConfiguration', $reply->{ws}->{$dn}->{bootconfiguration});

		#create boot files and lts.conf files
                $this->create_boot_file($reply->{ws}->{$dn}->{bootconfiguration},$dn);
	}
	return { TYPE => 'NOTICE', MESSAGE => 'pxe_written'};
}

sub create_boot_file
{
	my $this     = shift;
        my $bootconf = shift;
        my $dn       = shift;

        #get workstation hardwareaddres
        my $mac     = $this->get_attribute($dn,'dhcpHWAddress');
        $mac =~ s/ethernet //;
        my $hw     = $this->get_config_value($dn,'HW');

	if(($bootconf =~ /^LTS(.*)$/) or ($bootconf =~ /WTS(.*)$/)){
		my @terminalserver = split('/',$bootconf);
                $this->make_lts_file($terminalserver[0],$terminalserver[2],$mac,$hw);
                $this->make_boot_file($mac,'ltspboot');
        }elsif($bootconf eq 'cloneTool'){
		system("rm /srv/tftp/KIWI/lts.$mac");
                $this->make_boot_file($mac,'cloneTool');
        }elsif($bootconf eq 'Local'){
		system("rm /srv/tftp/KIWI/lts.$mac");
                $this->make_boot_file($mac,'localboot');
        }elsif($bootconf eq 'Autoinstallation'){
		system("rm /srv/tftp/KIWI/lts.$mac");
                $this->make_boot_file($mac,'autoinstallation');
        }
}

sub make_boot_file
{
	my $this = shift;
        my $mac      = shift;
        my $boot_tmp = shift;

        $mac =~ s/:/-/g;
        $mac = "01-".lc($mac);
        my $ltsp_boot = get_file("/usr/share/oss/templates/$boot_tmp");
	my $server_ip =  $this->get_school_config('SCHOOL_SERVER');
        $ltsp_boot =~ s/#SERVER_IP#/$server_ip/g;
        $ltsp_boot =~ s/#HWCONF#/$server_ip/g;
        write_file('/srv/tftp/pxelinux.cfg/'.$mac,$ltsp_boot);

}

sub make_lts_file
{
	my $this    = shift;
	my $ts_type = shift;
	my $ts_ip   = shift;
	my $ws_mac  = shift;
	my $ws_hw   = shift;

	if( -e "/srv/tftp/KIWI/lts.$ws_mac" ){
		system("rm /srv/tftp/KIWI/lts.$ws_mac");
	}

	if($ts_type eq 'LTS'){
		my $file = "/srv/tftp/KIWI/lts.lmd";
	        my $ini = Config::IniFiles->new( -file    => $file ) or die "Could not open $file!";
		if($ini->SectionExists( $ws_mac )){
			$this->make_conf_file($ws_mac, $ws_hw, $ts_ip, $ts_type);
                        $ini->setval($ws_mac, 'SERVER', $ts_ip);
		}else{
			$this->make_conf_file($ws_mac, $ws_hw, $ts_ip, $ts_type);
                        $ini->newval($ws_mac, 'SERVER', $ts_ip);
		}
		my $file_name = "/srv/tftp/KIWI/lts.$ws_mac";
	        $ini->WriteConfig($file_name);
	}
	elsif($ts_type eq 'WTS'){
		my $file = "/srv/tftp/KIWI/lts.rdesk";
                my $ini = Config::IniFiles->new( -file    => $file ) or die "Could not open $file!";
		if($ini->SectionExists( $ws_mac )){
			$this->make_conf_file($ws_mac, $ws_hw, $ts_ip, $ts_type);
                        $ini->setval($ws_mac, 'SCREEN_07', "\"rdesktop -a 16 $ts_ip\"");
		}else{
			$this->make_conf_file($ws_mac, $ws_hw, $ts_ip, $ts_type);
                        $ini->newval($ws_mac, 'SCREEN_07', "\"rdesktop -a 16 $ts_ip\"");
		}
		my $file_name = "/srv/tftp/KIWI/lts.$ws_mac";
	        $ini->WriteConfig($file_name);
	}
}

sub make_conf_file
{
	my $this    = shift;
	my $ws_mac  = shift;
	my $ws_hw   = shift;
	my $ts_ip   = shift;
	my $ts_type = shift;

        my $NBDROOT_file = get_file("/srv/tftp/KIWI/configNBDROOT");
	my $server_ip =  $this->get_school_config('SCHOOL_SERVER');
	if($ts_type eq 'LTS'){
		my $nbdroot_ip = "$ts_ip;2000";
		$NBDROOT_file =~ s/#NBDROOT#/$nbdroot_ip/;
	}elsif($ts_type eq 'WTS'){
		my $nbdroot_ip = "$server_ip;20000";
                $NBDROOT_file =~ s/#NBDROOT#/$nbdroot_ip/;
	}
	$NBDROOT_file =~ s/#lts_MAC#/$ws_mac/g;
	$NBDROOT_file =~ s/#lts_HW#/$ws_hw/g;
	$NBDROOT_file =~ s/#SERVER_IP#/$server_ip/g;
	write_file('/srv/tftp/KIWI/config.'.$ws_mac,$NBDROOT_file);
}

sub get_ws_or_room_type
{
	my $this = shift;
	my $dn_ws_or_room = shift;
	my $hwconf_ws_or_room = shift;
	my @terminalservers = @_;
	my $ws_or_room_type;
	my @BootConfig;

	my $WSType = $this->get_computer_config_value('WSType',      $hwconf_ws_or_room);
	my $descrp = $this->get_computer_config_value('description', $hwconf_ws_or_room);
        my $bootconf_tmp = $this->get_vendor_object($dn_ws_or_room,'EXTIS','BootConfiguration');
print "======== $hwconf_ws_or_room : $WSType :  $descrp : $bootconf_tmp \n";
        if( $WSType eq 'FatClient' ){
                 push @BootConfig, [@terminalservers, 'Local', 'cloneTool', 'Autoinstallation', '---DEFAULTS---', $bootconf_tmp->[0]];
                 $ws_or_room_type = 'FatClient/'.$descrp;
        }elsif( $WSType eq 'ThinClient' ){
                 @BootConfig = [ @terminalservers , '---DEFAULTS---', $bootconf_tmp->[0]];
                 $ws_or_room_type = 'ThinClient/'.$descrp;
        }elsif( $WSType eq 'LinuxTerminalServer' ){
                 push @BootConfig, ['Local', 'Autoinstallation', '---DEFAULTS---', $bootconf_tmp->[0]];
                 $ws_or_room_type = 'LinuxTerminalServer/'.$descrp;
        }elsif( $WSType eq 'WindowsTerminalServer' ){
                @BootConfig = [ 'Local' , '---DEFAULTS---', $bootconf_tmp->[0]];
		$ws_or_room_type = 'WindowsTerminalServer/'.$descrp;
	}

	my %return =( 
		'bootconfig',@BootConfig,
		'ws_or_room_type',$ws_or_room_type,
	);

	return \%return;
}

1;
