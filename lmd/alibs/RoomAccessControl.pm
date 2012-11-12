# LMD Room Access Control modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package RoomAccessControl;

use strict;
use oss_base;
use oss_utils;
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
		"clean",
		"set",
		"setAccessScheduler",
		"showAccessScheduler",
		"setRoomsAccess",
		"setRoomAccess",
		"select",
		"showRooms",
		"WOLCmd",
		"read"
	];

}

sub getCapabilities
{
	return [
		 { title        => 'Access Control' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { allowedRole  => 'teachers,sysadmins' },
		 { allowedRole  => 'teachers' },
		 { category     => 'Security' },
		 { order        => 1 },
		 { variable     => [ time     => [ type => 'time' ] ] },
		 { variable     => [ add      => [ type => 'boolean' ] ] },
		 { variable     => [ delete   => [ type => 'boolean' ] ] },
		 { variable     => [ default  => [ type => 'boolean' ] ] },
		 { variable     => [ all      => [ type => 'boolean' ] ] },
		 { variable     => [ mailing  => [ type => 'boolean' ] ] },
		 { variable     => [ printing => [ type => 'boolean' ] ] },
		 { variable     => [ proxy    => [ type => 'boolean' ] ] },
		 { variable     => [ samba    => [ type => 'boolean' ] ] },
		 { variable     => [ modify   => [ type => 'boolean' ] ] },
		 { variable     => [ label1   => [ type => 'label' ] ] },
		 { variable     => [ room     => [ type => 'label' ] ] },
		 { variable     => [ rooms    => [ type => 'popup' ] ] },
		 { variable     => [ ClientControl => [ type => 'translatedpopup' ] ] },
		 { variable     => [ modifydn => [ type => 'hidden' ] ] },
		 { variable     => [ showAccessScheduler => [ type => 'action' ]]},
		 { variable     => [ WOLCmd  => [ type => 'action' ]]}
	];
}

sub default
{
	my $this   = shift;
	my $reply  = shift;
	my $role   = main::GetSessionValue('role');
	if( $role =~ /^teachers/ )
	{
		$this->showMyRoom($reply);
	}
	elsif( $role =~ /^root|sysadmins$/ )
	{
		$this->showRooms($reply);
	}
}

sub showRooms
{
	my $this   = shift;
	my $reply  = shift;
	my $rooms       = $this->get_rooms('clients');
        my @lines       = ('rooms');

	if( ! $rooms  || !scalar(keys(%$rooms)))
	{
		return { TYPE     => 'NOTICE',
             		 MESSAGE  => 'no_rooms_defined',
			 MESSAGE1 => 'Please create rooms!'
			};
	}
        my @dns         = ();
        my %tmp         = ();

        foreach my $dn (keys %{$rooms})
        {
                $tmp{$rooms->{$dn}->{"description"}->[0]} = $dn;
        }
        foreach my $i ( sort keys %tmp )
        {
                push @dns, $tmp{$i};
        }
        foreach my $dn (@dns)
        {
		my $desc = $rooms->{$dn}->{"description"}->[0];
		my ( $all, $mail, $print, $proxy, $samba ) = $this->get_room_access_state($dn);
		if( defined $all )
		{
		push @lines, { line => [ $dn ,  { room     => $desc }, 
						{ modify   => 0} , 
						{ all      => $all} , 
						{ mailing  => $mail } , 
						{ printing => $print }, 
						{ proxy    => $proxy }, 
						{ samba    => $samba},
						{ showAccessScheduler => main::__('show') },
						{ WOLCmd  => main::__('WOLCmd ') } ]};
		}
		else
		{
		push @lines, { line => [ $dn ,  { room     => $desc }, 
						{ modify   => 0} , 
						{ mailing  => $mail } , 
						{ printing => $print }, 
						{ proxy    => $proxy }, 
						{ samba    => $samba},
						{ showAccessScheduler => main::__('show') },
						{ WOLCmd  => main::__('WOLCmd ') } ]};
		}
		
	}

        return
        [
	   { subtitle => 'Actuell Access State' },
           { table  =>  \@lines },
           { action => "cancel" },
	   { name   => 'action', value => "setRoomsAccess", attributes => [ label => 'apply' ] }
        ];

}

sub showMyRoom
{
	my $this   = shift;
	my $reply  = shift;
	my $room   = shift || main::GetSessionValue('room');
	my $LANG   = main::GetSessionValue('lang');
	$room      = $this->get_room_by_name($room);
	my ( $control, $controller, $controllers ) = $this->get_room_control_state($room);

	if( ! $room || $control eq 'no_control' )
	{
		return $this->chooseRoom();
	}
	else
	{
		my ( $all, $mail, $print, $proxy, $samba ) = $this->get_room_access_state($room);
		my @whiteLists = ();
		foreach my $wl ( @{$this->get_vendor_object($this->{roomDN},'oss','whiteLists')} )
		{
			my $label = get_name_of_dn($wl);
			my $des   = $this->get_attribute($wl,'description');
			if( $des  =~ /^NAME-$LANG=(.*)$/m)
			{
				$label = $1;
			}
			push @whiteLists, '"'.$label.'"';
		}
		my @lines = ('rooms');
		if( defined $all && main::isAllowed('RoomAccessControl.showMyRoom.all') )
		{
			push @lines, { line   =>  [ $room , { all => $all} , { mailing => $mail } , { printing => $print }, { proxy => $proxy }, { samba => $samba}] };
		}
		else
		{
			push @lines, { line   =>  [ $room , { mailing => $mail } , { printing => $print }, { proxy => $proxy }, { samba => $samba}] };
		}
		my @r = ( { subtitle => 'Actuell Access State' } );
		if( scalar(@whiteLists) > 1  )
		{
			push @r, { NOTRANSLATE_NOTICE => main::__('There are following WhiteLists activated in this Room:')."\n".join("\n",@whiteLists) };
		}
		push @r, { table  => \@lines };
		push @r, { action => "cancel" };
	        if( main::GetSessionValue('role') eq 'teachers,sysadmins' )
		{
			push @r, { action => "showRooms" };
		}
		push @r, { action => "WOLCmd" };
		#   { action => "openRoom" },
		push @r, { name   => 'action', value => "setRoomAccess", attributes => [ label => 'apply' ] };
		return \@r;
	}
}

sub chooseRoom
{
	my $this   = shift;
	my $reply  = shift;
	my $message= shift;
        $message .= main::__('You have to selet a room to control.');
	my @rooms  =  @{$this->get_free_mobile_rooms()};
        @rooms = ( @rooms,  @{$this->get_controlled_mobile_rooms()} );
	if( ! scalar @rooms )
	{
	        if( main::GetSessionValue('role') eq 'teachers,sysadmins' )
		{
			$this->showRooms();
		}
		else
		{
			return { 
				TYPE     => 'NOTICE',
             			MESSAGE  => 'control_only_in_classroom'
			};
		}
	}
	else
	{
		return
		[
			{ subtitle => 'Choose a room to control' },
			{ label    => $message },
			{ rooms    => \@rooms },
			{ action   => 'cancel' },
			{ action   => 'select' }
		];
	}
}

sub select
{
	my $this   = shift;
	my $reply  = shift;
	my $room   = $reply->{rooms} || '';
	if( ! $room )
	{
		return { TYPE     => 'NOTICE',
             		 MESSAGE  => 'control_only_in_classroom'
			};
	}
	else
	{
		( $room ) = split / /, $room;
		main::UpdateSessionData('room',$room);
		$this->free_mobile_room($room);
		$this->select_mobile_room($room);
		$this->showMyRoom($reply,$room);
	}
}

sub setRoomsAccess
{
	my $this   = shift;
	my $reply  = shift;
	my $ip   = main::GetSessionValue('ip');

	foreach my $dn ( keys %{$reply->{'rooms'}} )
	{
		next if ( ! $reply->{'rooms'}->{$dn}->{modify} );
		my $room = $reply->{'rooms'}->{$dn};
		$this->set_room_access_state($dn,'all',     $room->{all}     , $ip );
		$this->set_room_access_state($dn,'mailing', $room->{mailing} , $ip );
		$this->set_room_access_state($dn,'printing',$room->{printing}, $ip );
		$this->set_room_access_state($dn,'proxy',   $room->{proxy}   , $ip );
		$this->set_room_access_state($dn,'samba',   $room->{samba}   , $ip );
	}

	$this->default;
}

sub setRoomAccess
{
	my $this   = shift;
	my $reply  = shift;
	my $room   = main::GetSessionValue('room');
	$room      = $this->get_room_by_name($room);
	my $ip     = main::GetSessionValue('ip');

	$this->set_room_access_state($room,'all',     $reply->{rooms}->{$room}->{all}     , $ip );
	$this->set_room_access_state($room,'mailing', $reply->{rooms}->{$room}->{mailing} , $ip );
	$this->set_room_access_state($room,'printing',$reply->{rooms}->{$room}->{printing}, $ip );
	$this->set_room_access_state($room,'proxy',   $reply->{rooms}->{$room}->{proxy}   , $ip );
	$this->set_room_access_state($room,'samba',   $reply->{rooms}->{$room}->{samba}   , $ip );

	$this->default;
}

sub showAccessScheduler
{
	my $this   = shift;
	my $reply  = shift;
	my $dn	   = $reply->{line};
	my $acls   = $this->get_room_access_list($dn);
	my $desc   = $this->get_attribute($dn,'description');
	my @D	   = ('default');
	my @N	   = ('new' ,{ head => [ 'add',   'time','', 'all','mailing','printing','proxy','samba']});
	my @L      = ('acls',{ head => [ 'delete','time','', 'all','mailing','printing','proxy','samba']} );
	my @r      = ( { notranslate_subtitle => main::__('Edit Room Access State Scheduler').' '.$desc } );
	push @D , { line => [ 'DEFAULT' , {all      => $acls->{'DEFAULT'}->{'all'}},
					  {mailing  => $acls->{'DEFAULT'}->{'mailing'}},
					  {printing => $acls->{'DEFAULT'}->{'printing'}},
					  {proxy    => $acls->{'DEFAULT'}->{'proxy'}},
					  {samba    => $acls->{'DEFAULT'}->{'samba'}}]
		  };

	foreach my $time ( sort(keys(%{$acls})) )
	{
		next if ( $time eq 'DEFAULT' );
		if( $acls->{$time} eq 'DEFAULT' )
		{
			push @L , { line => [ $time , {delete => 0}, 
					  { time     => $time  },
					  { ClientControl => ClientControl('DEFAULT') }]
		  	};
		}
		elsif( defined $acls->{$time}->{'ClientControl'} )
		{
			push @L , { line => [ $time , {delete => 0}, 
					  { time          => $time  },
					  { ClientControl => ClientControl($acls->{$time}->{'ClientControl'}) }]
		  	};
		}
		else
		{
			push @L , { line => [ $time , {delete => 0}, 
					  { time     => $time  },
					  { label1   => '' },
					  { all      => $acls->{$time}->{'all'}},
					  { mailing  => $acls->{$time}->{'mailing'}},
					  { printing => $acls->{$time}->{'printing'}},
					  { proxy    => $acls->{$time}->{'proxy'}},
					  { samba    => $acls->{$time}->{'samba'}}]
			};
		}
	}
	push @N , { line => [ 'NEW' , {add => 0}, 
			  { time     => '00:00'  },
			  { ClientControl => ClientControl('-')},
			  { all      => $acls->{'DEFAULT'}->{'all'}},
			  { mailing  => $acls->{'DEFAULT'}->{'mailing'}},
			  { printing => $acls->{'DEFAULT'}->{'printing'}},
			  { proxy    => $acls->{'DEFAULT'}->{'proxy'}},
			  { samba    => $acls->{'DEFAULT'}->{'samba'}}]
	};
	push @r, { label    => 'Default Access Status' };
	push @r, { table    => \@D };
	push @r, { label    => 'Access Status Settings' } if (scalar(@L));
	push @r, { table    => \@L } if (scalar(@L));
	push @r, { label    => 'New Access Status' };
	push @r, { table    => \@N };
	push @r, { modifydn => $dn };
	push @r, { action   => 'cancel' };
	push @r, { name     => 'action', value => 'setAccessScheduler', attributes => [ label => 'apply' ] };

	return \@r;


}

sub setAccessScheduler
{
	my $this   = shift;
	my $reply  = shift;
	my $acls   = {};
	$acls->{DEFAULT}->{all} = $reply->{default}->{DEFAULT}->{all};
	$acls->{DEFAULT}->{proxy} = $reply->{default}->{DEFAULT}->{proxy};
	$acls->{DEFAULT}->{printing} = $reply->{default}->{DEFAULT}->{printing};
	$acls->{DEFAULT}->{mailing} = $reply->{default}->{DEFAULT}->{mailing};
	$acls->{DEFAULT}->{samba} = $reply->{default}->{DEFAULT}->{samba};
	foreach my $key ( keys %{$reply->{acls}} )
	{
	    next if ($reply->{acls}->{$key}->{delete});
	    if( defined $reply->{acls}->{$key}->{ClientControl} )
	    {
		if( $reply->{acls}->{$key}->{ClientControl} eq 'DEFAULT' )
		{
	        	$acls->{$key}->{DEFAULT} = 1;
		}
		elsif( $reply->{acls}->{$key}->{ClientControl} ne '-'  )
		{
			$acls->{$key}->{ClientControl} = $reply->{acls}->{$key}->{ClientControl};
		}
	    }
	    else
	    {
		$acls->{$key}->{all} = $reply->{acls}->{$key}->{all};
		$acls->{$key}->{proxy} = $reply->{acls}->{$key}->{proxy};
		$acls->{$key}->{printing} = $reply->{acls}->{$key}->{printing};
		$acls->{$key}->{mailing} = $reply->{acls}->{$key}->{mailing};
		$acls->{$key}->{samba} = $reply->{acls}->{$key}->{samba};
	    }
	}
	if( $reply->{'new'}->{NEW}->{add} )
	{
	    my $time = $reply->{'new'}->{NEW}->{'time'};
	    if( $reply->{'new'}->{NEW}->{ClientControl} ne '-' )
	    {
		if( $reply->{'new'}->{NEW}->{ClientControl} eq 'DEFAULT' )
		{
	        	$acls->{$time}->{DEFAULT} = 1;
		}
		else
		{
	        	$acls->{$time}->{ClientControl} = $reply->{'new'}->{NEW}->{ClientControl};
		}
	    }
	    else
	    {
		$acls->{$time}->{all} = $reply->{'new'}->{NEW}->{all};
		$acls->{$time}->{proxy} = $reply->{'new'}->{NEW}->{proxy};
		$acls->{$time}->{printing} = $reply->{'new'}->{NEW}->{printing};
		$acls->{$time}->{mailing} = $reply->{'new'}->{NEW}->{mailing};
		$acls->{$time}->{samba} = $reply->{'new'}->{NEW}->{samba};
	    }
	}
	$this->set_room_access_list($reply->{modifydn},$acls);
	$this->showAccessScheduler({ line => $reply->{modifydn}});
}

sub WOLCmd
{
        my $this    = shift;
        my $reply   = shift;
	my $room    = $reply->{line} || main::GetSessionValue('room');
        my $net     = new Net::Netmask( $this->get_school_config('SCHOOL_NETWORK'), $this->get_school_config('SCHOOL_NETMASK') );
        my $BC      = $net->broadcast();
        my @WSS     = ();
        foreach my $ws ( @{$this->get_workstations_of_room($room)} )
        {
                my $mac = $this->get_attribute($ws,'dhcpHWAddress');
                $mac =~ s/ethernet //;
                system("/usr/bin/wol -h $BC $mac");
                #print("/usr/bin/wol -h $BC $mac\n");
		sleep 1;
                push @WSS, get_name_of_dn($ws);
        }
        return {
                TYPE    => 'NOTICE',
                CODE    => 'WOLCmd_EXECUTED',
                NOTRANSLATE_MESSAGE => join( ' ', @WSS )
        };
}

sub ClientControl($)
{
	my $i = shift;
	my @c = ('-','DEFAULT','ShutDownCmdSHUTDOWN','ShutDownCmdREBOOT','ShutDownCmdLOGOFF','WOLCmd','---DEFAULTS---',$i);
	if( ! -e '/etc/init.d/oss-clax' )
	{
		@c = ('-','DEFAULT','WOLCmd','---DEFAULTS---',$i);
	}
	return \@c;
}
1;
