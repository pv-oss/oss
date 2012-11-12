# OSS Room Configuration Module
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ManageRooms; 

use strict;
use oss_user;
use oss_utils;
use Net::LDAP::Entry;
use Data::Dumper;
use DBI;
use Net::Netmask;
use MIME::Base64;
use Storable qw(thaw freeze);

use vars qw(@ISA);
@ISA = qw(oss_user);

my @DHCPOptions = qw(
all-subnets-local
arp-cache-timeout
bootfile-name
boot-size
broadcast-address
cookie-servers
default-ip-ttl
default-tcp-ttl
dhcp-client-identifier
dhcp-lease-time
dhcp-max-message-size
dhcp-message
dhcp-message-type
dhcp-option-overload
dhcp-parameter-request-list
dhcp-rebinding-time
dhcp-renewal-time
dhcp-requested-address
dhcp-server-identifier
domain-name
domain-name-servers
extensions-path
finger-server
font-servers
host-name
ieee802-3-encapsulation
ien116-name-servers
impress-servers
interface-mtu
ip-forwarding
irc-server
log-servers
lpr-servers
mask-supplier
max-dgram-reassembly
merit-dump
mobile-ip-home-agent
nds-context
nds-servers
nds-tree-name
netbios-dd-server
netbios-name-servers
netbios-node-type
netbios-scope
nis-domain
nis-servers
nisplus-domain
nisplus-servers
nntp-server
non-local-source-routing
ntp-servers
nwip-domain
nwip-suboptions
path-mtu-aging-timeout
path-mtu-plateau-table
perform-mask-discovery
policy-filter
pop-server
resource-location-servers
root-path
router-discovery
router-solicitation-address
routers
slp-directory-agent
slp-service-scope
smtp-server
space
static-routes
streettalk-directory-assistance-server
streettalk-server
subnet-mask
subnet-selection
swap-server
tcp-keepalive-garbage
tcp-keepalive-interval
tftp-server-name
time-offset
time-servers
trailer-encapsulation
uap-servers
user-class
vendor-class-identifier
vendor-encapsulated-options
www-server
x-display-manager
);

my @DHCPStatements = qw(
allow
always-broadcast
authoritative
ddns-update-style
default-lease-time
deny
filename
get-lease-hostnames
use-host-decl-names
if
include
max-lease-time
next-server
option
range
type
);

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    my $self    = oss_user->new($connect);
    $self->{RADIUS} = ($self->get_school_config('SCHOOL_USE_RADIUS') eq 'yes') ? 1 : 0;
    return bless $self, $this;
}

sub interface
{
        return [
                "addNewPC",
                "addNewRoom",
                "addPC",
                "addRoom",
                "control",
                "default",
                "del_room",
                "DHCP",
                "getCapabilities",
                "modifyRoom",
                "realy_delete",
                "room",
                "roomGeometry",
                "roomType",
                "scanPCs",
                "setControl",
		"setDHCP",
                "setRoomGeometry",
                "setRooms",
                "setRoomType",
		"setWlanUser",
		"change_room",
		"apply_change_room",
		"selectWlanUser",
		"setWlanUser",
		"ANON_DHCP",
		"insert_in_to_room",
        ];
}

sub getCapabilities
{
        return [
                { title        => 'Managing the Rooms' },
                { type         => 'command' },
                { allowedRole  => 'root' },
                { allowedRole  => 'sysadmins' },
                { allowedRole  => 'teachers' },
                { allowedRole  => 'teachers,sysadmins' },
                { category     => 'Network' },
		{ order        => 10 },
		{ variable     => [ 'freerooms',    [ type => 'popup' ]] },
		{ variable     => [ 'rooms',        [ type => 'popup' ]] },
		{ variable     => [ 'dhcpOptions',  [ type => 'popup' ]] },
		{ variable     => [ 'dhcpStatements',[ type => 'popup' ]] },
		{ variable     => [ 'description',  [ type => 'label'  ] ]},
		{ variable     => [ 'hwaddress',    [ type => 'string'  ] ]},
		{ variable     => [ 'network',      [ type => 'label', ] ]},
		{ variable     => [ 'addNewPC',     [ type => 'action' ] ]},
		{ variable     => [ 'ANON_DHCP',    [ type => 'action' ] ]},
		{ variable     => [ 'DHCP',         [ type => 'action' ] ]},
		{ variable     => [ 'hwconfig',     [ type => 'popup', style => 'width:180px;' ]]  },
		{ variable     => [ 'teachers',     [ type => 'list', size => '15', multiple=>"true" ]]  },
		{ variable     => [ 'control_mode', [ type => 'translatedpopup' ]]  },
		{ variable     => [ 'dn',           [ type => 'hidden' ]]  },
		{ variable     => [ 'roomtype',     [ type => 'hidden' ]]  },
		{ variable     => [ 'set_free',     [ type => 'boolean' ]]  },
		{ variable     => [ 'room',         [ type => 'action' ]] },
		{ variable     => [ 'control',      [ type => 'action' ]] },
		{ variable     => [ 'del_room',     [ type => 'action', label => 'delete' ]] },
		{ variable     => [ 'workstations', [ type => 'list', size => '10' ]]  },
		{ variable     => [ 'hwaddresses',  [ type => 'text', rows => '10', cols => '20'  ]]},
		{ variable     => [ 'wlanaccess',   [ type => 'boolean' ]]},
		{ variable     => [ 'master',       [ type => 'boolean' ]]},
		{ variable     => [ 'delete',       [ type => 'boolean' ]]},
		{ variable     => [ 'change_room',  [ type => 'action' ]]},
		{ variable     => [ 'apply_change_room',  [ type => 'action', label => 'apply_change_room' ]]},
		{ variable     => [ 'free_busy',          [ type => 'img', style => 'margin-right:80px;' ]]},
	];
}

sub default
{
	my $this 	= shift;
	my $reply	= shift;
	my $rooms	= undef; 
	my $role	= main::GetSessionValue('role');
	if( main::GetSessionValue('role') eq 'teachers' )
	{
		$rooms = $this->get_rooms(main::GetSessionValue('dn'));
	}
	else
	{
		$rooms = $this->get_rooms('all');
	}
	my @lines       = ('rooms');
	my @dns         = ();
	my %tmp		= ();

	foreach my $dn (keys %{$rooms})
	{
		$tmp{$rooms->{$dn}->{"description"}->[0]} = $dn;
	}
	push @lines, { head => [
                	{ name => 'room',    attributes => [ label => main::__('room'),    help => main::__('Push the button to edit the room') ] },
                	{ name => 'network', attributes => [ label => main::__('network')] },
                 	{ name => 'add',     attributes => [ label => main::__('add'),     help => main::__('Push the button to add a new workstation to the room') ] },
                	{ name => 'DHCP',    attributes => [ label => 'DHCP',              help => main::__('Push the button to set special DHCP parameter for the room.') ] },
                	{ name => 'hwconfig',attributes => [ label => main::__('hwconfig'),help => main::__('Select the standard workstation configuration for the room.') ] },
                	{ name => 'control', attributes => [ label => main::__('control'), help => main::__('Push the button to edit control method for the room.') ] },
			{ name => 'free_busy',  attributes => [ label => main::__('Free/Busy'),  help => main::__('If theres a tick mark then theres nobody logged into the clients PC in the given classroom. If theres an X mark then somebody is logged into the clients PC on that particular classroom.') ] },
                	{ name => 'delete',  attributes => [ label => main::__('delete'),  help => main::__('Push the button to delete room with all workstations.') ] }
			]
		};

	system("/usr/share/oss/tools/clean-up-sambaUserWorkstations.pl");
	foreach my $i ( sort keys %tmp )
	{
		my $dn = $tmp{$i};
		my @hwconf   = @{$this->get_HW_configurations(1)};
		#my $cn       = $rooms->{$dn}->{"cn"}->[0];
		my $desc     = $rooms->{$dn}->{"description"}->[0];
		my $network  = $rooms->{$dn}->{"dhcprange"}->[0].'/'.$rooms->{$dn}->{'dhcpnetmask'}->[0];
		my ( $control, $controller, $controllers )  = $this->get_room_control_state($dn);
		my $hw       = $this->get_config_value($dn,'HW') || '-';
		push @hwconf,  [ '---DEFAULTS---' ], [ $hw ];
		my $img = '';
		my $logged_users = $this->get_logged_users("$dn");
		if( !keys %{$logged_users} ){
			$img = `base64 /srv/www/oss/img/accept.png`;
		}
		foreach my $dn (sort keys %{$logged_users} ){
			if( exists($logged_users->{$dn}->{user_name})){
				$img = `base64 /srv/www/oss/img/delete.png`;
				last;
			}else{
				$img = `base64 /srv/www/oss/img/accept.png`;
			}
		}

		if( $desc =~ /^ANON_DHCP/ )
		{
			my $result = $this->{LDAP}->search( base => $this->{SYSCONFIG}->{DHCP_BASE}, filter => 'cn=Pool1' );
			if(defined $result && $result->count() > 0)
			{
		    		$dn = $result->entry(0)->dn;
				push @lines, { line => [ $dn , { description => $desc } , {network => $network}, {ANON_DHCP=>main::__('add')}, { DHCP=>'DHCP'} ]}; 
			}
		}
		elsif( $desc =~ /^SERVER_NET/ )
		{
			push @lines, { line => [ $dn , {room => $desc } , {network => $network}, {addNewPC=>main::__('add')}, { DHCP=>'DHCP'} ]}; 
		}
		else
		{
			push @lines, { line => [ $dn ,  {room => $desc }, {network => $network}, {addNewPC=>main::__('add')}, { DHCP=>'DHCP'},
							{ hwconfig => \@hwconf }, {control => main::__($control)} , { free_busy => "$img" },
							{ del_room => main::__('delete') } ]}; 
		}
	}
	if( scalar(@lines) > 1)
	{
		return 
		[
		   { table  =>  \@lines },
		   { action => "scanPCs" },
		   { action => "addNewRoom" },
		   { action => "setRooms" }
		];
	}
	else
	{
		return 
		[
		   { action => "scanPCs" },
		   { action => "addNewRoom" },
		   { action => "setRooms" }
		];
	}
}

sub DHCP
{
	my $this 	= shift;
	my $reply	= shift;
	my $ENTRY	= $this->get_entry($reply->{line});
	my $st		= $ENTRY->{description}->[0] || $ENTRY->{cn}->[0];
	my @r		= ( { subtitle => 'DHCP '.$st }, { NOTICE => main::__('Please be carefull! Bad entries can destroy the DHCP configuration.') });
	my @options	= ( 'options'    , { head => [ 'DHCP-Option', 'Value' , 'Delete' ] } );
	my @statements	= ( 'statements' , { head => [ 'DHCP-Statement', 'Value', 'Delete' ] });
	if( defined $ENTRY->{dhcprange} && $ENTRY->{cn}->[0] =~ /^Pool/ ){
		push @r, { dhcprange => $ENTRY->{dhcprange}->[0] };
	}
	if( defined $ENTRY->{dhcpoption} )
	{
		my $i = 0;
		foreach(@{$ENTRY->{dhcpoption}})
		{
			my ( $o, $v ) = split / /,$_,2;
			push @options , { line => [ $i , { option => $o }, { value => $v } , { delete => 0 } ] }; 
			$i++;
		}
		push @r, { label => main::__('DHCP-Options') };
		push @r, { table => \@options };
	}
	if( defined $ENTRY->{dhcpstatements} )
	{
		my $i = 0;
		foreach(@{$ENTRY->{dhcpstatements}})
		{
			my ( $o, $v ) = split / /,$_,2;
			push @statements , { line => [ $i , { statements => $o } , { value => $v }, { delete => 0 } ] }; 
			$i++;
		}
		push @r, { label => main::__('DHCP-Statements') };
		push @r, { table => \@statements };
	}
	push @r, { label => main::__('Add New DHCP-Option') };
	push @r, { table => [ 'newOption' , { head => [ 'DHCP-Options', 'Value' ] }, { line => [ 0, { dhcpOptions => \@DHCPOptions }, { value => '' } ] } ] };
	push @r, { label => main::__('Add New DHCP-Statement') };
	push @r, { table => [ 'newStatement' , { head => [ 'DHCP-Statement', 'Value' ] }, { line => [ 0, { dhcpStatements => \@DHCPStatements }, { value => '' } ] } ] };
	push @r, { dn    => $reply->{line} };
	push @r, { action => 'cancel' };
	push @r, { name => 'action', value => 'setDHCP', attributes => [ label => 'apply'] };
	return \@r;

}

sub setDHCP
{
	my $this 	= shift;
	my $reply	= shift;
	my @options     = ();
	my @statements  = ();
	if( defined $reply->{options} )
	{
		foreach my $i ( keys %{$reply->{options}} )
		{
			next if ( $reply->{options}->{$i}->{delete} );
			if( length( $reply->{options}->{$i}->{value} ) )
			{
				push @options, $reply->{options}->{$i}->{option}.' '.$reply->{options}->{$i}->{value};
			}
			else
			{
				push @options, $reply->{options}->{$i}->{option};
			}
		}
	}
	if( defined $reply->{statements} )
	{
		foreach my $i ( keys %{$reply->{statements}} )
		{
			next if ( $reply->{statements}->{$i}->{delete} );
			if( length( $reply->{statements}->{$i}->{value} ) )
			{
				push @statements, $reply->{statements}->{$i}->{statements}.' '.$reply->{statements}->{$i}->{value};
			}
			else
			{
				push @statements, $reply->{statements}->{$i}->{statements};
			}
		}
	}
	if( $reply->{newOption}->{0}->{dhcpOptions} )
	{
		push @options, $reply->{newOption}->{0}->{dhcpOptions}.' '.$reply->{newOption}->{0}->{value};
	}
	if( $reply->{newStatement}->{0}->{dhcpStatements} )
	{
		push @statements, $reply->{newStatement}->{0}->{dhcpStatements}.' '.$reply->{newStatement}->{0}->{value};
	}
	$this->{LDAP}->modify( $reply->{dn} , delete => { dhcpStatements => [] } );
	$this->{LDAP}->modify( $reply->{dn} , delete => { dhcpOption => [] } );
	$this->{LDAP}->modify( $reply->{dn} , add => { dhcpStatements => \@statements } ) if( scalar @statements );
	$this->{LDAP}->modify( $reply->{dn} , add => { dhcpOption => \@options } )        if( scalar @options );
	if( defined $reply->{dhcprange} )
	{
		$this->{LDAP}->modify( $reply->{dn} , replace => { dhcprange => $reply->{dhcprange} } );
	}
	$reply->{dn} =~ /cn=config1,cn=(.*),ou=DHCP/;
        my $server = ($1 eq 'schooladmin') ? undef : $1;
        $this->rc("dhcpd","restart",$server);
	$this->DHCP( { line => $reply->{dn} } );
}

sub realy_delete
{
	my $this 	= shift;
	my $reply	= shift;
	$reply->{realy_delete} = 1;
	$this->del_room($reply);
}

sub del_room
{
	my $this 	= shift;
	my $reply	= shift;
	my $dn          = $reply->{line} || $reply->{dn};
	my $description = $this->get_attribute($dn,'description');
	my $ws		= $this->get_workstations_of_room($dn);

	if( scalar(@{$ws}) && ! $reply->{realy_delete} )
	{
		return [
			{ notranslate_label => $description },
			{ label  => 'There are workstations in this room. These will be deleted too. Do you realy want to delete it?' },
			{ dn     => $dn },
			{ action => 'cancel' },
			{ name   => 'action' ,  value => 'realy_delete', attributes => [ label => 'delete'] }
		];
	}

	$this->delete_room( $dn );
	$this->default();
}

sub setRooms
{
	my $this 	= shift;
	my $reply	= shift;

	foreach my $dn (keys %{$reply->{rooms}})
	{
		if( $reply->{rooms}->{$dn}->{hwconfig} )
		{
			my @values = $this->get_attribute($dn,'configurationValue');
			if( ! scalar @values )
			{
				$this->{LDAP}->modify( $dn, add => { configurationValue => 'HW='.$reply->{rooms}->{$dn}->{hwconfig} } );
			}
			else
			{
				if( grep(/^HW=/,@values) )
				{
					grep {s/^HW=.*/HW=$reply->{rooms}->{$dn}->{hwconfig}/} @values;
				}
				else
				{
					push @values, 'HW='.$reply->{rooms}->{$dn}->{hwconfig};
				}
				$this->{LDAP}->modify( $dn, replace => { configurationValue => \@values });
			}
		}
	}
	$this->default;

}

sub room
{
	my $this 	= shift;
	my $reply	= shift;
	my %hosts	= ();
	my @lines	= ('ws');
	my $description = $this->get_attribute($reply->{line},'description');

	foreach my $dn ( @{$this->get_workstations_of_room($reply->{line})} )
	{
		my $hostname = $this->get_attribute($dn,'cn');
		my $hwaddress= $this->get_attribute($dn,'dhcpHWAddress');
		my $ipaddr   = $this->get_attribute($dn,'dhcpStatements');
		$hwaddress =~ s/ethernet //i;
		$ipaddr =~ s/fixed-address //i;
		if( $hostname )
		{
		   $hosts{$hostname}->{hwaddress} = $hwaddress;
		   $hosts{$hostname}->{ipaddr}    = $ipaddr;
		   $hosts{$hostname}->{dn}        = $dn;
		}
	}
	foreach my $hostname (sort keys(%hosts))
        {
		my $hw       = $this->get_config_value($hosts{$hostname}->{dn},'HW') || '-';
		my @hwconf   = @{$this->get_HW_configurations(1)};
		push @hwconf,  [ '---DEFAULTS---' ], [ $hw ] ;
		my $master   = ( $this->get_config_value($hosts{$hostname}->{dn},'MASTER')     eq "yes" ) ? 1 : 0;
		if( $this->{RADIUS} )
		{
			my $wlan     = ( $this->get_config_value($hosts{$hostname}->{dn},'WLANACCESS') eq "yes" ) ? 1 : 0;
			push @lines, { line => [ $hosts{$hostname}->{dn}, 
						{ description => $hostname },
						{ hwaddress   => $hosts{$hostname}->{hwaddress} }, 
						{ hwconfig    => \@hwconf }, 
						{ DHCP	      => 'DHCP' },
						{ master      => $master }, 
						{ wlanaccess  => $wlan },
						{ change_room => main::__('change_room')},
						{ delete      => 0 }
				  ]};
		}
		else
		{
			push @lines, { line => [ $hosts{$hostname}->{dn}, 
						{ description => $hostname }, 
						{ name => 'hwaddress', value => $hosts{$hostname}->{hwaddress}, attributes => [type => 'string'] },
						{ hwconfig    => \@hwconf }, 
						{ DHCP	      => 'DHCP' },
						{ master      => $master },
						{ change_room => main::__('change_room')},
						{ delete      => 0 } 
				  ]};
		}
	}
	return 
	[
	   { subtitle => $description }, 
	   { table    =>  \@lines },
	   { dn       => $reply->{line} },
	   { action   => "cancel" },
	   { action   => "addNewPC" },
	   { action   => "roomType" },
	   { action   => "roomGeometry" },
	   { name => 'action' , value  => 'modifyRoom', attributes => [ label => 'apply' ]  }
	];

}

sub modifyRoom
{
	my $this 	= shift;
	my $reply	= shift;
	$reply->{line}  = $reply->{dn};
	my $ERROR	= undef;
	my $deleted	= 0;

	foreach my $dn ( keys %{$reply->{ws}} )
	{
		if( $reply->{ws}->{$dn}->{delete} )
		{
			$deleted = 1;
			$this->delete_host($dn);
			next;
		}
		my $master = $reply->{ws}->{$dn}->{master}     ? 'yes' : 'no';
		$this->set_config_value($dn,'MASTER',$master);
		if( $this->{RADIUS} )
		{
			my $wlan   = $reply->{ws}->{$dn}->{wlanaccess} ? 'yes' : 'no';
			$this->set_config_value($dn,'WLANACCESS',$wlan);
		}
		$this->set_config_value($dn,'HW',$reply->{ws}->{$dn}->{hwconfig});
		my $hw     = $reply->{ws}->{$dn}->{hwaddress};
		if( check_mac( $hw ) )
		{
			my $result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DHCP_BASE},
					   filter => "(&(!(cn=".get_name_of_dn($dn)."))(dhcpHWAddress=ethernet $hw))",
					   attrs  => ['cn']
					 );
			if($result->count() > 0)
			{
		    		my $cn = $result->entry(0)->get_value('cn');
				$ERROR .= main::__("The hardware address already exists.")."$cn => $hw<br>";
			}
			else
			{
				$this->set_attribute($dn,'dhcpHWAddress','ethernet '.$hw);
			}
		}
		else
		{
			$ERROR .= get_name_of_dn($dn).': '.main::__('The hardware address is invalid').': '.$hw.'<br>';
		}
		
	}
        $reply->{dn} =~ /cn=config1,cn=(.*),ou=DHCP/;
        my $server = ($1 eq 'schooladmin') ? undef : $1;
        if( $deleted )
        {
                $this->rc("named","restart",$server);
        	$this->rc("named","restart") if( !undef $server );
        }
        $this->rc("dhcpd","restart",$server);
	if( $ERROR )
	{
           return {
                TYPE    => 'NOTICE',
                CODE    => 'ERROR_BY_MODIFYING_ROOM',
                NOTRANSLATEMESSAGE => $ERROR
           }
	}
	$this->room($reply);
}

sub roomType
{
	my $this 	= shift;
	my $reply	= shift;
	my $roomtype    = $this->get_vendor_object($reply->{dn},'EXTIS','ROOMTYPE');
	my ( $t, $r, $c ) = ( 'A', '' ,'' );
	if( defined $roomtype->[0] )
	{
	    ( $t, $r, $c ) = split /:/, $roomtype->[0];
	}

	return
	[
		{ subtitle => 'Choose Room Type' },
		{ dn       => $reply->{dn} },
		#TODO We have to discuss if we need it
		#{ name     => 'type' ,  value  => [ 'A', 'B', 'C', '---DEFAULTS---', $t ] , attributes => [ type => 'popup' ] },
		{ name     => 'type' ,  value  => 'A', attributes => [ type => 'hidden' ] },
		{ Columns  => $c },
		{ Rows	   => $r },
		{ action   => "cancel" },
		{ name => 'action' , value  => 'setRoomType', attributes => [ label => 'apply' ]  }
	];
}

sub setRoomType
{
	my $this 	= shift;
	my $reply	= shift;
	$this->create_vendor_object($reply->{dn},'EXTIS','ROOMTYPE',$reply->{type}.':'.$reply->{Rows}.':'.$reply->{Columns});
	$reply->{line} = $reply->{dn};
	$this->room($reply);
}

sub roomGeometry
{
	my $this 	= shift;
	my $reply	= shift;
	my @lines	= ('ws');
	my $roomtype    = $this->get_vendor_object($reply->{dn},'EXTIS','ROOMTYPE');

        if( !defined $roomtype->[0] )
	{
		return
		[
			{ subtitle => 'Choose Room Type' },
			{ dn       => $reply->{dn} },
			#TODO We have to discuss if we need it
			#{ name     => 'type' ,  value  => [ 'A', 'B', 'C', '---DEFAULTS---', $t ] , attributes => [ type => 'popup' ] },
			{ name     => 'type' ,  value  => 'A', attributes => [ type => 'hidden' ] },
			{ rows	   => '' },
			{ columns  => '' },
	        	{ action   => "cancel" },
			{ name => 'action' , value  => 'setRoomType', attributes => [ label => 'apply' ]  }
		 ];
	}

	foreach my $dn ( keys %{$reply->{ws}} )
	{
		my $x = -1;
		my $y = -1 ;
		my $xy = $this->get_vendor_object($dn,'EXTIS','COORDINATES');
		if( defined $xy->[0] )
		{
			( $x,$y ) = split /,/ , $xy->[0];
		}
		push @lines, { line => [ $dn , { x => $x } , { y => $y } ] };
	}
	if( scalar(@lines) > 1 )
	{
		return
		[
			{ subtitle => 'roomGeometry' },
			{ table    =>  \@lines },
			{ dn       => $reply->{dn} },
			{ roomtype => $roomtype->[0] },
			{ action   => "cancel" },
			{ name => 'action' , value  => 'setRoomGeometry', attributes => [ label => 'apply' ]  }
		];	
	}
	else
	{
		return
		[
			{ subtitle => 'roomGeometry' },
			{ dn       => $reply->{dn} },
			{ roomtype => $roomtype->[0] },
			{ action   => "cancel" },
			{ name => 'action' , value  => 'setRoomGeometry', attributes => [ label => 'apply' ]  }
		];	
	}
}

sub setRoomGeometry
{
	my $this 	= shift;
	my $reply	= shift;
	$reply->{line}  = $reply->{dn};

	foreach my $dn ( keys %{$reply->{ws}} )
	{
		my $xy = $reply->{ws}->{$dn}->{x}.','.$reply->{ws}->{$dn}->{y};
		$this->create_vendor_object($dn,'EXTIS','COORDINATES',$xy);
	}
	$this->create_vendor_object($reply->{dn},'EXTIS','ROOMTYPE',$reply->{roomtype});
	$this->room($reply);
}

sub addNewRoom
{
	my $this 	= shift;
	my $reply	= shift;
	my $free	= $this->get_free_rooms();
	my $hwconf      = $this->get_HW_configurations(1);
	my %tmp		= ();
	my @freerooms   = ();

	foreach my $dn (keys %{$free})
	{
		$tmp{$free->{$dn}->{"dhcprange"}->[0].'/'.$free->{$dn}->{'dhcpnetmask'}->[0]} = $dn;
	}
	foreach my $key ( sort keys %tmp )
	{
	       push @freerooms, [ $tmp{$key}, $key ];
	}
	push @freerooms, '---DEFAULTS---', $tmp{( sort keys %tmp )[0]};
	return [ 
		{ subtitle  => 'Add New Room'}, 
		{ new_room  => '' }, 
		{ freerooms => \@freerooms }, 
		{ hwconfig  => $hwconf },
		{ action    => 'cancel' },
		{ action    => 'addRoom' }
	];
}

sub addRoom
{
	my $this 	= shift;
	my $reply	= shift;
	my $dn		= $reply->{freerooms};
	my $new_room	= $reply->{new_room};
	if( length($new_room) > 10 ) 
	{
           return {
                TYPE    => 'ERROR',
                CODE    => 'NAME_TOO_LONG',
                MESSAGE => 'Room Name too Long'
           }
	}
	if( $new_room =~ /[^a-zA-Z0-9-]+/  || length($new_room)<2 ) {
           return {
                TYPE    => 'ERROR',
                CODE    => 'INVALID_NAME',
                MESSAGE => 'Room Name contains invalid characters or is too short'
           }
	}
	my $result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DHCP_BASE},
					    filter => "(description=$new_room)",
				            attrs  => ['cn']
				 );
	if($result->count() > 0)
	{
	    return { TYPE => 'ERROR' ,
		     CODE => 'ROOM_ALREADY_EXISTS',
		     MESSAGE => "This room already exists."
	           };
	}
	if( ! $this->add_room($dn,$new_room,$reply->{hwconfig}) )
	{
           return {
                TYPE    => 'ERROR',
                CODE    => $this->{ERROR}->{code},
                MESSAGE => $this->{ERROR}->{text}
           }
	}
	$this->default();
}

sub control
{
	my $this 	= shift;
	my $reply	= shift;
	my @teachers    = ();
	foreach my $i ( sort @{$this->get_school_users('teachers')} )
	{
		push @teachers, [ $i ,  $this->get_attribute($i,'uid')." ".$this->get_attribute($i,'cn')];  
	}
	my $description = $this->get_attribute($reply->{line},'description');
	my ( $control, $controller, $controllers )  = $this->get_room_control_state($reply->{line});
	my $cont = $this->get_attribute($controller,'uid')." ".$this->get_attribute($controller,'cn');
	push @teachers, '---DEFAULTS---', @{$controllers};
	return 
	[
	    { notranslate_subtitle      => $description }, 
	    { control_mode  => [ 'in_room_control' , 'no_control', 'all_teacher_control' ,'teacher_control', '---DEFAULTS---', $control ] },
	    { label         => 'Choose the teachers who can control this Room' },    
	    { teachers      => \@teachers },
	    { controller    => $cont },
	    { set_free      => 0 },
	    { dn            => $reply->{line} },
	    { name => 'action' , value => "cancel",     attributes => [ label => 'back' ] },
	    { name => 'action' , value => "setControl", attributes => [ label => 'apply' ]  }
	];
}

sub setControl
{
	my $this 	= shift;
	my $reply	= shift;
	my $Entry	= $this->get_entry($reply->{dn},1);
	my $controller	= undef;
	$reply->{line}  = $reply->{dn};

	#first we clean the corresponding configurationValues
	foreach my $cV ( $Entry->get_value('configurationValue'))
	{
	   if( $cV =~ /^NO_CONTROL|^MAY_CONTROL=/ )
	   {
	       $Entry->delete( configurationValue=> [ $cV ]);
	   }
	   elsif (  $cV =~ /^CONTROLLED_BY=.*/i )
	   {
	   	$controller = $cV;
	   }
	}
	if( $Entry->exists( 'writerdn' ) )
	{
		$Entry->delete( writerdn => [] );
	}
	# now we set the new controll status
	if( $reply->{control_mode} eq 'all_teacher_control' )
	{
	    $Entry->add( configurationValue=>'MAY_CONTROL=@teachers' );
	}
	elsif( $reply->{control_mode}  eq 'no_control' )
	{
	    $Entry->add( configurationValue=>'NO_CONTROL' );
	}
	elsif( $reply->{control_mode} eq 'teacher_control' )
	{
	    foreach my $dn ( split /\n/, $reply->{teachers} )
	    {
	        $Entry->add( configurationValue=>'MAY_CONTROL='.$dn );
		$Entry->add( writerdn=>$dn );
	    }
	}
	if( $controller && ( $reply->{control_mode}  =~ /^no_control|in_room_control$/ ||  $reply->{set_free}) )
	{
		$Entry->delete( configurationValue=> [ $controller ]);
	}
	$Entry->update($this->{LDAP});
	$this->control($reply);
}

sub addNewPC
{
	my $this 	= shift;
	my $reply	= shift;
	my $room	= $reply->{line} || $reply->{dn};
        if( $room !~ /^cn=Room/ )
	{
		$room = $this->get_room_by_name($room);
	}
	my $ip		= main::GetSessionValue('ip');
	my $block       = new Net::Netmask($this->{SYSCONFIG}->{SCHOOL_SERVER_NET});
	my $new_ip      = '';
	my $hostname    = '';
	my $dhcpHWAddress = '';

	if(  ! $block->match($ip) ) {
	    my $tmp = `/sbin/arp -a $ip`;
	    $tmp =~ /(\w\w:\w\w:\w\w:\w\w:\w\w:\w\w)/;
	    $dhcpHWAddress = $1;
	}

	#Get the room
	my @hosts      = $this->get_free_pcs_of_room($room);
        if ( ! scalar @hosts )
        {
                return {
                        TYPE => 'ERROR' ,
                        CODE => 'NO_MORE_FREE_ADDRESS_IN_ROOM',
                        MESSAGE => 'There are no more free addresses in this room.'
                };
        }
        my   $hw       = $this->get_config_value($room,'HW') || '-';
	my   @hwconf   = @{$this->get_HW_configurations(1)};
	push @hwconf,  [ '---DEFAULTS---' ], [ $hw ];
	push @hosts, '---DEFAULTS---', $hosts[0];
	if( $this->{RADIUS} )
	{
		return [ 
			{ subtitle     => 'Add New PC'}, 
			{ workstations => \@hosts   },
			{ hwaddresses  => $dhcpHWAddress },
			{ hwconfig     => \@hwconf },
			{ master       => 0 },
			{ wlanaccess   => 0 },
			{ other_name   => '' },
			{ dn           => $room },
			{ action       => 'cancel' },
			{ action       => 'addPC' }
		];
	}
	else
	{
		return [ 
			{ subtitle     => 'Add New PC'}, 
			{ workstations => \@hosts   },
			{ hwaddresses  => $dhcpHWAddress },
			{ hwconfig     => \@hwconf },
			{ master       => 0 },
			{ other_name   => '' },
			{ dn           => $room },
			{ action       => 'cancel' },
			{ action       => 'addPC' }
		];
	}
}

sub addPC
{
	my $this 	= shift;
	my $reply	= shift;
	my @HWS         = split /\n/, $reply->{hwaddresses};
	my @hosts       = @{thaw(decode_base64(main::GetSessionDatas('hosts')))};
	my $result	= '';
	my $host	= shift @hosts;
	my $HOSTDN	= undef;
	my $domain	= $this->{SYSCONFIG}->{SCHOOL_DOMAIN};

	if( scalar( @HWS ) > 1 && $reply->{other_name} ne '' )
	{
	    return { TYPE    => 'ERROR' ,
	    	     CODE    => 'TO_MANY_MAC_ADDRESS',
		     MESSAGE => "If registering a computer with alternete name, you may only use one hardware address."
	    };
	}
	# check the alternate name
	if( $reply->{other_name} ne '' )
	{
		if( $reply->{other_name} =~ /[^a-zA-Z0-9-]+/ ||
		    $reply->{other_name} !~ /^[a-zA-Z]/      ||
		    $reply->{other_name} =~ /-$/             ||
		    length($reply->{other_name})<2           ||
		    length($reply->{other_name}) > 15  )
		{
		    return { TYPE    => 'ERROR' ,
			     CODE    => 'INVALID_HOST_NAME',
			     MESSAGE => "The alternate host name is invalid."
	                   };
		}
		$result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DNS_BASE},
				   filter => 'relativeDomainName='.$reply->{other_name},
				   attrs  => ['aRecord']
				 );
		if($result->count() > 0)
		{
		    return { TYPE => 'ERROR' ,
			     CODE => 'HOST_ALREADY_EXISTS',
			     MESSAGE => "The alternate host name already exists.",
			     NOTRANSLATEMESSAGE1 => "IP: ".$result->entry(0)->get_value('aRecord')
	                   };
		}
                if(!$this->is_unique($reply->{other_name},'uid'))
                {
                    return { TYPE => 'ERROR' ,
                             CODE => 'NAME_ALREADY_EXISTS',
                             MESSAGE => "The alternate host name will be used allready as userid."
                           };
                }

	}

	#seeking $hosts to the choosen host
	if($reply->{workstations} ne '')
	{
	   while( $reply->{workstations} ne $host && $host ne '' )
	   {
	      $host = shift @hosts;
	   }
	}

	#Now we do our work
	foreach my $hw (@HWS)
	{
		$hw = uc($hw);
		if( !check_mac($hw) )
		{
		    return { TYPE => 'ERROR' ,
			     CODE => 'HW_ADDRESS_INVALID',
			     MESSAGE => "The hardware address is invalid",
			     MESSAGE1 => $hw,
	                   };
		}
		my $result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DHCP_BASE},
				   filter => "(dhcpHWAddress=ethernet $hw)",
				   attrs  => ['cn']
				 );
		if($result->count() > 0)
		{
		    my $cn = $result->entry(0)->get_value('cn');
		    return { TYPE => 'ERROR' ,
			     CODE => 'HW_ALREADY_EXISTS',
			     MESSAGE  => "The hardware address already exists.",
			     NOTRANSLATE_MESSAGE1 => "$cn => $hw"
	                   };
		}
		my ( $name,$ip ) = split /:/, $host;
		if( $reply->{other_name} ne '' )
		{
			$name = $reply->{other_name};
		}
		my @dns = $this->add_host($name.'.'.$domain,$ip,$hw,$reply->{hwconfig},$reply->{master},$reply->{wlanaccess});
		$HOSTDN = $dns[$#dns];
		if( ! $this->add( { uid          	   => $name,
			     sn			   => $name.' Workstation-User',
			     role         	   => 'workstations',
			     userpassword 	   => $name,
			     sambauserworkstations => $name
			   } ))
		{
			print STDERR $this->{ERROR}->{text}."\n";
		}
		if( ! $this->add( { uid        	   => $name.'$',
			     sn			   => 'Machine account '.$name ,
			     description	   => 'Machine account '.$name ,
			     role         	   => 'machine',
			     userpassword 	   => '{crypt}*'
			   } ) )
		{
			print STDERR $this->{ERROR}->{text}."\n";
		}
		$host = shift @hosts;
	}
        $reply->{dn} =~ /cn=config1,cn=(.*),ou=DHCP/;
        my $server = ($1 eq 'schooladmin') ? undef : $1;
        $this->rc("named","reload",$server);
        $this->rc("named","reload") if( defined $server );
        $this->rc("dhcpd","restart",$server);
        $reply->{line} = $reply->{dn};
	if(exists($reply->{flag}))
	{
		return $HOSTDN;
	}
	else
	{
		if( $reply->{wlaneccess} && scalar( @HWS ) == 1 )
		{
			$reply->{HOSTDN} = $HOSTDN;
			$this->selectWlanUser($reply);
		}
		else
		{
			$this->room($reply);
		}
	}
}

sub scanPCs
{
	my $this   = shift;
	my $reply  = shift;
	my $rooms  = $this->get_rooms('all');
	my @srooms = ();
	my %tmp    = ();
	my @hwconf = @{$this->get_HW_configurations(1)};
	my $hw     = $reply->{hwconfig} || "default";
	foreach my $dn (keys %{$rooms})
	{
		$tmp{$rooms->{$dn}->{"description"}->[0]} = $dn;
	}
	foreach my $i ( sort keys %tmp )
	{
		push @srooms, [ $tmp{$i} , $i ];
		
	}
	if( defined $reply->{rooms} ) {
		push @srooms, [ '---DEFAULTS---'], [ $reply->{rooms} ]; 
	}
	if( !$reply->{rooms} || !defined $reply->{continue} )
	{

		return [
				{ subtitle  => 'Scan New PCs'}, 
				{ label     => 'Please select the room and datas to collect' },
				{ name      => 'rooms',     value => \@srooms,  attributes => [ type  => 'popup', focus=>1 ] },
				{ name      => 'bserial',   value => 1,         attributes => [ type  => 'boolean' ] },
				{ name      => 'binventar', value => 1,         attributes => [ type  => 'boolean' ] },
				{ name      => 'bposition', value => 0,         attributes => [ type  => 'boolean' ] },
				{ name      => 'bimaging',  value => 1,         attributes => [ type  => 'boolean', label => 'Start Imaginig' ] },
				{ name      => 'continue',  value => 1,         attributes => [ type  => 'hidden' ] },
				{ name      => 'action',    value => 'scanPCs', attributes => [ label => 'start' ] },
				{ action    => 'cancel' }
		];
	}
	if( defined $reply->{hwconfig} && $reply->{hwconfig} eq 'default' ) {
		$hw = $this->get_config_value($reply->{rooms},'HW')
	}
	push @hwconf,  [ 'default','Room Default' ], [ '---DEFAULTS---' ], [ $hw ];
	my @ret = ();
	my $focus = 0;
	push @ret, { subtitle  => 'Scan New PC'};
	push @ret, { rooms     => \@srooms }; 
	push @ret, { hwconfig  => \@hwconf };
	if( $reply->{hwaddresses} eq '' )
	{
		$focus = 'hwaddresses';
	}
	if( $reply->{bserial} ) {
		if( $reply->{serial} eq '' && !$focus )
		{
			$focus = 'serial';
		}
	}
	if( $reply->{binventar} ) {
		if( $reply->{inventar} eq '' && !$focus )
		{
			$focus = 'inventar';
		}
	}
	if( $reply->{bposition} ) {
		if( $reply->{row} eq '' && !$focus )
		{
			$focus = 'row';
		}
		if( $reply->{column} eq '' && !$focus )
		{
			$focus = 'column';
		}
	}
	if( !$focus )
	{ # We have all the datas
		$reply->{flag} = 1;
		$reply->{dn}   = $reply->{rooms};
		my @hosts      = $this->get_free_pcs_of_room($reply->{rooms});
		$reply->{hwaddresses} =~ /([0-9a-f]{2})[-:]?([0-9a-f]{2})[-:]?([0-9a-f]{2})[-:]?([0-9a-f]{2})[-:]?([0-9a-f]{2})[-:]?([0-9a-f]{2})/i;
		$reply->{hwaddresses} = "$1:$2:$3:$3:$5:$6";
		my $dn         = $this->addPC($reply);
		if( ref $dn eq 'HASH')
		{
			return $dn;
		}
		$this->create_vendor_object($dn,'EXTIS','SERIALNUMBER',$reply->{serial}) 		   if( $reply->{bserial} );
		$this->create_vendor_object($dn,'EXTIS','INVENTARNUMBER', $reply->{inventar}) 		   if( $reply->{binventar} );
		$this->create_vendor_object($dn,'EXTIS','COORDINATES', $reply->{row}.','.$reply->{column}) if( $reply->{bposition} );
		if( $reply->{bimaging} )
		{
			system("echo 'workstation $dn\npartitions all\n' | /usr/sbin/oss_restore_workstations.pl");
		}
		$reply->{hwaddresses} = '';
		$focus = 'hwaddresses';
		$reply->{serial}      = '';
		$reply->{inventar}    = '';
		$reply->{row}         = '';
		$reply->{column}      = '';
	}
	if( 'hwaddresses' eq $focus )
	{
		push @ret, { name => 'hwaddresses', value => '', attributes => [ type  => 'string', focus => 1 ] };
	}
	else
	{	
		push @ret, { name => 'hwaddresses', value => $reply->{hwaddresses} || '' , attributes => [ type  => 'string' ] };
	}
	if( $reply->{bserial} ) {
		if( $focus eq 'serial' )
		{
			push @ret, { name => 'serial', value => '', attributes => [ type  => 'string', focus => 1 ] };
		}
		else
		{
			push @ret, { serial => $reply->{serial} || '' };
		}
	}
	if( $reply->{binventar} ) {
		if( $focus eq 'inventar' )
		{
			push @ret, { name => 'inventar', value => '', attributes => [ type  => 'string', focus => 1 ] };
		}
		else
		{
			push @ret, { inventar  => $reply->{inventar} || '' };
		}
	}
	if( $reply->{bposition} ) {
		if( $focus eq 'row' )
		{
			push @ret, { name => 'row', value => '', attributes => [ type  => 'string', focus => 1 ] };
		}
		else
		{
			push @ret, { row       => $reply->{row} || '' };
		}
		if( $focus eq 'column' )
		{
			push @ret, { name => 'column', value => '', attributes => [ type  => 'string', focus => 1 ] };
		}
		else
		{
			push @ret, { column       => $reply->{column} || '' };
		}
	}
	push @ret, { name      => 'bserial',   value => $reply->{bserial},   attributes => [ type  => 'hidden' ] };
	push @ret, { name      => 'binventar', value => $reply->{binventar}, attributes => [ type  => 'hidden' ] };
	push @ret, { name      => 'bposition', value => $reply->{bposition}, attributes => [ type  => 'hidden' ] };
	push @ret, { name      => 'bimaging',  value => $reply->{bimaging},  attributes => [ type  => 'hidden' ] };
	push @ret, { name      => 'continue',  value => 1,         attributes => [ type  => 'hidden' ] };
	push @ret, { name      => 'action',    value => 'scanPCs', attributes => [ label => 'continue' ] };
	push @ret, { action    => 'cancel' };
	return \@ret;
}
sub selectWlanUser
{
	my $this  = shift;
	my $reply = shift;
	if( $reply->{FILTERED} )
	{
		my $name  = $reply->{name} || '*';
		my @role  = split /\n/, $reply->{role}  || ();
		my @group = split /\n/, $reply->{workgroup} || ();
		my @class = split /\n/, $reply->{class} || ();
		my $user        = $this->search_users($name,\@class,\@group,\@role);
		my @users	= ();
		foreach my $dn ( sort keys %{$user} )
        	{
                	push @users , [ $dn, $user->{$dn}->{uid}->[0].' '.$user->{$dn}->{cn}->[0].' ('.$user->{$dn}->{description}->[0].')' ];
        	}
		my @ret = ({ subtitle    => 'Select the User for this WLAN Device!' } );
		push @ret, { user => \@users }; 
		push @ret, { name => 'rightaction', value => "selectWlanUser",   attributes => [ label => 'searchAgain' ]  };
		push @ret, { name => 'rightaction', value => "setWlanUser",      attributes => [ label => 'apply' ]  };
		push @ret, { name => 'rightaction', value => "room",             attributes => [ label => 'cancel' ]  };
		push @ret, { name => 'HOSTDN',      value => $reply->{HOSTDN},   attributes => [ type  => 'hidden' ] };
		push @ret, { name => 'line',        value => $reply->{line},     attributes => [ type  => 'hidden' ] };
		return \@ret;
	}
	else
	{
		my ( $roles, $classes, $workgroups ) = $this->get_school_groups_to_search();
		my @ret = ({ subtitle    => 'Search User' } );
		push @ret, { name        => '*' };
		push @ret, { role        => $roles};
		push @ret, { class       => $classes };
		push @ret, { workgroup   => $workgroups };
		push @ret, { name => 'rightaction', value => "selectWlanUser", attributes => [ label => 'search' ]  };
		push @ret, { name => 'HOSTDN',      value => $reply->{HOSTDN},   attributes => [ type  => 'hidden' ] };
		push @ret, { name => 'line',        value => $reply->{line},     attributes => [ type  => 'hidden' ] };
		push @ret, { name => 'FILTERED',    value => 1,                  attributes => [ type  => 'hidden' ] };
		return \@ret;

	}
}

sub setWlanUser
{
	my $this  = shift;
	my $reply = shift;
	my $HW    = uc($this->get_attribute($reply->{HOSTDN},'dhcpHWAddress'));
	$HW =~ s/ethernet //i;
        $HW =~ s/:/-/g;
	$this->{LDAP}->modify($reply->{user}, delete => { rassAccess => 'no' } );
	$this->{LDAP}->modify($reply->{user}, delete => { rassAccess => 'all' } );
	$this->{LDAP}->modify($reply->{user}, add    => { rassAccess => $HW } );
	$this->room($reply);
}

sub host_exists
{
        my $this = shift;
        my $host = shift;
        my $res = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DNS_BASE},
                                         scope  => 'sub',
                                         filter => "relativeDomainName=$host",
                                         attrs  => [] );
        return $res->count if( !$res->code );
        return 0;

}

sub ip_exists
{
	my $this = shift;
	my $ip   = shift;
	return 1 if($this->get_workstation($ip));
        my $res = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DNS_BASE},
                                         scope  => 'sub',
                                         filter => "ARecord=$ip",
                                         attrs  => [] );
        return $res->count if( !$res->code );
	return 0;

}

sub change_room
{
	my $this  = shift;
	my $reply = shift;
	my @ret = ( 'change_room' );

	my $hwaddress = $this->get_attribute($reply->{line},'dhcpHWAddress');
        $hwaddress =~ s/ethernet //i;
	my $ipaddr   = $this->get_attribute($reply->{line},'dhcpStatements');
	$ipaddr =~ s/fixed-address //i;

#print Dumper($reply)." a change room reply-e\n";
	my $hostname = $this->get_attribute($reply->{line},'cn');
	my $message = sprintf( main::__('To move the workstation "%s"/"%s" into an other room, please select a room from the list below and press the button'), $hostname, $hwaddress ).' "'.main::__('apply_change_room').'".';
	my $rooms = $this->get_rooms('all');
	my @room_list;
	my $roomDN = $this->get_room_of_ip($ipaddr);
	my $roomname = $this->get_attribute($roomDN,'description');

        foreach my $dn (keys %{$rooms})
        {
		if( ($rooms->{$dn}->{"description"}->[0] !~ /^ANON_DHCP/ ) and 
		    ($rooms->{$dn}->{"description"}->[0] !~ /^SERVER_NET/) and 
		    ($rooms->{$dn}->{"description"}->[0] ne "$roomname") )
		{
			push @room_list, [ $dn, $rooms->{$dn}->{"description"}->[0]]
		}
        }

	return [
		{ subtitle => "$hostname"},
		{ NOTICE => "$message"},
		{ name => 'room', value => [@room_list], attributes => [ type => 'popup' ]},
		{ action => 'cancel'},
		{ action => 'apply_change_room'},
		{ name => 'current_pc_dn', value => "$reply->{line}", attributes => [ type => 'hidden']},
	];
}

sub apply_change_room
{
	my $this  = shift;
	my $reply = shift;

	#get old_pc informations
        my $old_pc_bootconf = $this->get_vendor_object($reply->{current_pc_dn},'EXTIS','BootConfiguration');
	my $old_hostname = $this->get_attribute($reply->{current_pc_dn},'cn');
	my $other_name = '';
	if( $reply->{current_pc_dn} =~ /^cn=([^,]*),(.*)/){
		my $old_room_desc = $this->get_attribute( "$2",'description');
		if($old_hostname !~ /^(.*)-(.*)$/){
			$other_name = $old_hostname;
		}
	}
        my $old_hwaddress = $this->get_attribute($reply->{current_pc_dn},'dhcpHWAddress');
	$old_hwaddress =~ s/ethernet //i;
	my $old_hwconf    = $this->get_config_value($reply->{current_pc_dn},'HW') || '-';
	my $old_master    = ( $this->get_config_value($reply->{current_pc_dn},'MASTER') eq "yes" ) ? 1 : 0;
	my $old_wlan      = ( $this->get_config_value($reply->{current_pc_dn},'WLANACCESS') eq "yes" ) ? 1 : 0;

	my $room = $reply->{room};
        if( $room !~ /^cn=Room/ )
        {
                $room = $this->get_room_by_name($room);
        }
        my $ip          = main::GetSessionValue('ip');
        my $block       = new Net::Netmask($this->{SYSCONFIG}->{SCHOOL_SERVER_NET});
        my $new_ip      = '';
        my $hostname    = '';

        #Get the room
        my $roomnet   = $this->get_attribute($room,'dhcpRange').'/'.$this->get_attribute($room,'dhcpNetMask');
        my $roompref  = $this->get_attribute($room,'description');
        $block = new Net::Netmask($roomnet);
        my @hosts      = ();
        my %lhosts     = ();
        my $base       = $block->base();
        my $broadcast  = $block->broadcast();
        my $counter    = -1;
        foreach my $i ($block->enumerate()) {
                if(  $i ne $base && $i ne $broadcast ) {
                        $counter ++;
                        next if ( $this->ip_exists($i) );
                        next if ( $roompref =~ /^SERVER_NET/ && $counter < 10 );
                        my $hostname = lc(sprintf("$roompref-pc%02d",$counter));
                        $hostname =~ s/_/-/;
			next if ( $this->host_exists($hostname) );
                        push @hosts, $hostname.':'.$i;
                }
        }
        my $freeze = encode_base64(freeze(\@hosts),"");
        main::AddSessionDatas($freeze,'hosts');

	$this->delete_host($reply->{current_pc_dn});
	$room =~ /cn=config1,cn=(.*),ou=DHCP/;
        my $server = ($1 eq 'schooladmin') ? undef : $1;
        $this->rc("named","restart",$server);
        $this->rc("named","restart") if( !undef $server );
        $this->rc("dhcpd","restart",$server);

        if( $this->{RADIUS} )
        {
		$reply->{workstations} = $hosts[0];
		$reply->{hwaddresses} = $old_hwaddress;
		$reply->{hwconfig} = $old_hwconf;
		$reply->{master} = $old_master;
		$reply->{wlanaccess} = $old_wlan;
		$reply->{other_name} = $other_name;
		$reply->{dn} = $room;
		$reply->{flag} = '1';
		$this->addPC($reply);
        }
        else
        {
		$reply->{workstations} = $hosts[0];
                $reply->{hwaddresses} = $old_hwaddress;
                $reply->{hwconfig} = $old_hwconf;
                $reply->{master} = $old_master;
                $reply->{other_name} = $other_name;
                $reply->{dn} = $room;
		$reply->{flag} = '1';
		$this->addPC($reply);
        }

	my $new_pc_dn   = $this->get_workstation("$old_hwaddress");
	my $new_hostname = $this->get_attribute($new_pc_dn,'cn');

	#set new pc BootConfiguration
        if($old_pc_bootconf->[0] ne ''){
                $this->create_vendor_object( $new_pc_dn, 'EXTIS','BootConfiguration', $old_pc_bootconf->[0]);
        }

	#set pc_name in the OSSInv_PC and OSSInv_PC_Info tables
	my $sth = $this->{DBH}->prepare("SELECT Id FROM OSSInv_PC WHERE PC_Name=\"$old_hostname\" and MacAddress=\"$old_hwaddress\"");   $sth->execute;
	my $result = $sth->fetchrow_hashref();
	my $pc_id = $result->{Id};
	$sth = $this->{DBH}->prepare("UPDATE OSSInv_PC SET PC_Name=\'$new_hostname\' WHERE Id=\"$pc_id\";");   $sth->execute;

	$sth = $this->{DBH}->prepare("SELECT Id, PC_Name, Info_Category_Id, Value FROM OSSInv_PC_Info WHERE PC_Name=\'$old_hostname\'");   $sth->execute;
	my $pc_info = $sth -> fetchall_hashref( 'Id' );
	foreach my $info_id (keys %{$pc_info}){
		$sth = $this->{DBH}->prepare("UPDATE OSSInv_PC_Info SET PC_Name=\'$new_hostname\' WHERE Id=\"$info_id\";");   $sth->execute;
	}

	$reply->{line} = $room;
	$this->room($reply);
	
}

sub ANON_DHCP
{
	my $this  = shift;
	my $reply = shift;

	#get annon_dhcp workstations
	my $file_content = `cat /var/lib/dhcp/db/dhcpd.leases`;
	my @sections = split("lease ", $file_content);
	my %hash = ('anon_PCs');
	foreach my $section (@sections){
		next if($section !~ /^[0-9](.*)/);
		my @lines = split("\n", $section);
		$section =~/(.*)hardware ethernet (.*);\n(.*)/;
		my $mac_address = $2;

		foreach my $line (@lines){
			$line =~ s/^\s+//;
			if( $line =~/^([0-9](.*)) \{/ ){
				$hash{anon_PCs}->{$mac_address}->{ip_address} = "$1";
			}
			if( $line =~/^client-hostname "(.*)";/ ){
				$hash{anon_PCs}->{$mac_address}->{client_hostname} = "$1";
			}
		}
	}

	#get free hosts
	my @hosts = ();
	my $rooms = $this->get_rooms();
	foreach my $room_dn ( keys %{$rooms} ){
		my $roomnet   = $this->get_attribute($room_dn,'dhcpRange').'/'.$this->get_attribute($room_dn,'dhcpNetMask');
		my $roompref  = $this->get_attribute($room_dn,'description');
		my $block = new Net::Netmask($roomnet);
		my $base       = $block->base();
		my $broadcast  = $block->broadcast();
		my $counter    = -1;
		foreach my $i ($block->enumerate()) {
			if(  $i ne $base && $i ne $broadcast ) {
				$counter ++;
				next if ( $this->ip_exists($i) );
				next if ( $roompref =~ /^SERVER_NET/ && $counter < 10 );
				my $hostname = lc(sprintf("$roompref-pc%02d",$counter));
				$hostname =~ s/_/-/;
				next if ( $this->host_exists($hostname) );
				push @hosts, $hostname.':'.$i;
			}
		}
	}
	my $freeze = encode_base64(freeze(\@hosts),"");
	main::AddSessionDatas($freeze,'hosts');

	#create table content
	my @lines = ('anon_DHCP');
	push @lines, { head => [ 'rooms', 'other_name', 'hwaddresses', 'hwconfig', 'master' ] };
	foreach my $mac ( keys %{$hash{anon_PCs}}){
		my $netcard_vendor = $this->get_vendor_netcard("$mac");
		my $result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DHCP_BASE},
                                   filter => "(dhcpHWAddress=ethernet $mac)",
                                   attrs  => ['cn']
                                 );
		next if($result->count() > 0);
		my   @hwconf   = @{$this->get_HW_configurations(1)};
		push @hwconf,  [ '---DEFAULTS---' ], [ '-' ];
		if( $this->{RADIUS} ){
			push @lines, { line => [ $mac,
						{ name => 'workstations', value => \@hosts, attributes => [ type => 'popup'] },
						{ other_name   => "$hash{anon_PCs}->{$mac}->{client_hostname}" },
						{ name => 'hwaddresses', value => $mac, attributes => [ type => 'label', help => "$netcard_vendor"] },
						{ hwconfig     => \@hwconf },
						{ master       => 0 },
						{ wlanaccess   => 0 },
				]};
		}else{
			push @lines, { line => [ $mac,
						{ name => 'workstations', value => \@hosts, attributes => [ type => 'popup'] },
						{ other_name   => "$hash{anon_PCs}->{$mac}->{client_hostname}" },
						{ name => 'hwaddresses', value => $mac, attributes => [ type => 'label', help => "$netcard_vendor"] },
						{ hwconfig     => \@hwconf },
						{ master       => 0 },
				]};
		}
	}

	#return page
	my @ret;
	if( scalar(@lines) < 3){
		push @ret, { subtitle => 'ANON_DHCP' };
		push @ret, { NOTICE   => main::__('Does not have workstations in the "ANON_DHCP" room!') };
		push @ret, { action   => "cancel" };
	}else{
		if( exists($reply->{warning}) ){
			push @ret, { NOTICE => $reply->{warning} };
		}
		push @ret, { subtitle => 'ANON_DHCP' };
		push @ret, { table    =>  \@lines };
		push @ret, { action   => "cancel" };
		push @ret, { name => 'action' , value  => 'insert_in_to_room', attributes => [ label => 'apply' ] };
	}
	return \@ret;
}

sub insert_in_to_room
{
	my $this  = shift;
	my $reply = shift;

	my $flag = 0;
	my @duplicate_ip_address;
	foreach my $workstation (keys %{$reply->{anon_DHCP}}){
		print $workstation."\n";
		my ( $tmp, $ip ) = split(":", $reply->{anon_DHCP}->{$workstation}->{workstations} );
		if( $this->ip_exists($ip) ){
			push @duplicate_ip_address, $workstation;
			next;
		}
		if( $reply->{anon_DHCP}->{$workstation}->{workstations} ){
			my $hash;
			$hash->{workstations} = $reply->{anon_DHCP}->{$workstation}->{workstations};
			$hash->{hwaddresses} = $workstation;
			$hash->{hwconfig} = $reply->{anon_DHCP}->{$workstation}->{hwconfig};
			$hash->{master} = $reply->{anon_DHCP}->{$workstation}->{master};
			if( exists($this->{anon_DHCP}->{$workstation}->{wlanaccess}) ){
				$hash->{wlanaccess} = $this->{anon_DHCP}->{$workstation}->{wlanaccess};
			}
			$hash->{other_name} = $reply->{anon_DHCP}->{$workstation}->{other_name};
			my ( $room_name, @tmp) = split("-", $hash->{workstations});
			my $room_dn = $this->get_room_by_name("$room_name");
			$hash->{dn} = $room_dn;
			$hash->{flag} = '1';
			$this->addPC($hash);
			$flag = 1;
		}
	}

	if( !$flag ){
                $reply->{warning} =  main::__('Please choose a workstation and choose which room you want to add this workstation!');
	}

	if( scalar(@duplicate_ip_address) ){
		my $workstations = join ", ",@duplicate_ip_address;
		$reply->{warning} = sprintf( main::__('Please choose another workstation name (workstationname:ipaddress), in order to add it to the following workstations : "%s"'),  $workstations );
	}
	return $this->ANON_DHCP($reply);
}

sub get_vendor_netcard
{
	my $this = shift;
	my $mac  = shift;
	my $vendor_netcard = '';

	$mac = uc($mac);
	$mac =~ /([0-9A-Z]{2}):([0-9A-Z]{2}):([0-9A-Z]{2})(.*)/;
	$mac = "$1-$2-$3";

	#first get
	if( !(-e "/tmp/mac_info") ){
		cmd_pipe("wget -O /tmp/mac_info http://standards.ieee.org/develop/regauth/oui/oui.txt");
	}
	$vendor_netcard = cmd_pipe("cat /tmp/mac_info | grep $mac | awk '{ print \$3\" \"\$4\" \"\$5\" \"\$6\" \"\$7}'");
	if( !$vendor_netcard ){
		cmd_pipe("wget -O /tmp/mac_info http://standards.ieee.org/develop/regauth/oui/oui.txt");
		$vendor_netcard = cmd_pipe("cat /tmp/mac_info | grep $mac | awk '{ print \$3\" \"\$4\" \"\$5\" \"\$6\" \"\$7}'");
	}

	#second get
	if( !$vendor_netcard ){
		cmd_pipe("wget -O /tmp/mac_info_2 http://www.coffer.com/mac_find/?string=$mac");
		my $mac_info = cmd_pipe("cat /tmp/mac_info_2 | grep '<td class=\"table2\"><a href='");
		my @arr_inf = split("<", $mac_info);
		$arr_inf[2] =~ /(.*)>(.*)/;
		$vendor_netcard = $2;
	}

	return $vendor_netcard;
}

sub get_free_pcs_of_room 
{
	my $this = shift;
	my $room = shift;
	my @hosts= ();
	my $roomnet    = $this->get_attribute($room,'dhcpRange').'/'.$this->get_attribute($room,'dhcpNetMask');
	my $roompref   = $this->get_attribute($room,'description');
	my $block      = new Net::Netmask($roomnet);
	my %lhosts     = ();
	my $schoolnet  = $this->get_school_config('SCHOOL_NETWORK').'/'.$this->get_school_config('SCHOOL_NETMASK');
	my $sblock     = new Net::Netmask($schoolnet);
	my $base       = $sblock->base();
	my $broadcast  = $sblock->broadcast();
	my $counter    = -1;
	foreach my $i ( $block->enumerate() )
	{
		if(  $i ne $base && $i ne $broadcast )
		{
			$counter ++;
			next if ( $this->ip_exists($i) );
			next if ( $roompref =~ /^SERVER_NET/ && $counter < 10 );
			my $hostname = lc(sprintf("$roompref-pc%02d",$counter));
			$hostname =~ s/_/-/;
			next if ( $this->host_exists($hostname) );
			push @hosts, $hostname.':'.$i;
		}
	}
	my $freeze = encode_base64(freeze(\@hosts),"");
	main::AddSessionDatas($freeze,'hosts');
	return @hosts;
}
1;
