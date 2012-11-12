# OSS Printer Management Module
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ManagePrinter; 

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
		"get_printers",
		"jobs_waiting",
		"enable_disable",
		"reset_printer",
		"delete_jobs",
		"adm_trusts",
		"setup_trusts",
		"apply_trusts",
		"rooms",
		"set_rooms",
		"back",
		"next",
		"firstpage",
		"lastpage",
		"install_driver",
		"en_air_print",
		"dis_air_print",
		"delete_printer",
        ];
}

sub getCapabilities
{
        return [
                { title        => 'Print Server Administration' },
                { type         => 'command' },
                { allowedRole  => 'root' },
                { allowedRole  => 'sysadmins' },
                { allowedRole  => 'teachers,sysadmins' },
                { category     => 'Network' },
		{ order        => 10 },
		{ variable     => [ 'printer',       [type => 'label'] ]},
		{ variable     => [ 'description ',  [type => 'label'] ]}, 
		{ variable     => [ 'location',      [type => 'label'] ]}, 
		{ variable     => [ 'jobs_waiting',  [type => 'action'] ]},
		{ variable     => [ 'enable_disable',[type => 'action'] ]}, 
		{ variable     => [ 'reset_printer', [type => 'action', label => 'reset'] ]}, 
		{ variable     => [ 'delete_jobs',   [type => 'action'] ]}, 
		{ variable     => [ 'adm_trusts',    [type => 'action'] ]},
		{ variable     => [ 'setup_trusts',  [type => 'action'] ]},
		{ variable     => [ 'apply_trusts',  [type => 'action'] ]},
		{ variable     => [ 'per_user_quota',[type => 'string', backlabel=>'Pages']] },
		{ variable     => [ 'quota_period',  [type => 'string', backlabel=>'Days']] },
		{ variable     => [ 'room',          [type => 'list', size =>'5', multiple => 'true' ] ]},
		{ variable     => [ 'allowed_user',  [type => 'list', size =>'10', multiple => 'true' ] ]},
		{ variable     => [ 'allowed_group', [type => 'list', size =>'10', multiple => 'true' ] ]},
		{ variable     => [ 'denied_user',   [type => 'list', size =>'10', multiple => 'true' ] ]},
		{ variable     => [ 'denied_group',  [type => 'list', size =>'10', multiple => 'true' ] ]},
		{ variable     => [ 'aprinter',      [type => 'list', size =>'5', multiple => 'true' ] ]},
		{ variable     => [ 'allow',         [type => 'translatedpopup', label =>'allow / deny' ] ]},
		{ variable     => [ 'current_page',  [type => 'hidden' ] ]},
		{ variable     => [ 'page_number',   [type => 'hidden' ] ]},
		{ variable     => [ 'next',          [type => 'action', label => 'next'] ]},
		{ variable     => [ 'back',          [type => 'action', label => 'back'] ]},
		{ variable     => [ 'firstpage',     [type => 'action', label => 'first'] ]},
		{ variable     => [ 'lastpage',      [type => 'action', label => 'last'] ]},
		{ variable     => [ 'install_driver',[type => 'action', label => 'install_printer_driver'] ]},
		{ variable     => [ 'en_air_print',  [type => 'action', label => 'air_print'] ]},
		{ variable     => [ 'dis_air_print', [type => 'action', label => 'air_print'] ]},
		{ variable     => [ 'delete_printer',[type => 'action', label => 'delete'] ]},
	];
}

sub default
{
	my $this 	= shift;
	my $reply	= shift;
	my $printers	= $this->get_printers();
	my $defaultp	= $printers->{DEFAULT};
	my @lines       = ('printers');
	my $role   = main::GetSessionValue('role');
	my $prt = $this->check_pid_cupsaddsmb();
	if( $prt ){
		return [
			{ NOTICE => sprintf( main::__('The activation of windows printer driver is in progress for printer "%s". Please, try it later.'), $prt ) }
		]
	}
	push @lines, { head => [ { name => "printer", attributes => [ label => main::__('printer')]},
				 { name => "description", attributes => [ label => main::__('description')]},
				 { name => 'location', attributes => [ label => main::__('location'), help => main::__('Location for the printer.') ] },
				 { name => "jobs_waiting", attributes => [ label => main::__('jobs_waiting'), help => main::__('The number of pending jobs.')]},
				 { name => "enable_disable", attributes => [ label => main::__('enable_disable'), help => main::__('Enable or disable the printer usage. (If we either enable or disable then refresh the page within 15-20 sec so we can see the changes)')]},
				 { name => "reset_printer", attributes => [ label => main::__('reset_printer'), help => main::__('Setting the printer into default mode.')]},
		]};
	if( $role =~ /^sysadmins/ ){
		push @{$lines[1]->{head}}, { name => "install_driver", attributes => [ label => main::__('install_driver'), help => main::__('Install or Uninstall the cups printer driver. If we install it then it will be reachable for a users PC through the samba. If we unistall it or it is not installed at all then it would not be reachable through the Samba server.')]};
		my $flag = $this->get_school_config("SCHOOL_ENABLE_AVAHI_PRINTER_CONFIG");
		if(!$flag){
                                $this->add_school_config('SCHOOL_ENABLE_AVAHI_PRINTER_CONFIG',"yes",'Enable/Disable avahi printer configuration','yesno','no','Settings');
		}
		if($flag eq "yes"){
			push @{$lines[1]->{head}}, { name => "en_air_print", attributes => [ label => main::__('en_air_print'), help => main::__('Enable or Disable the Air_Printer service. This way a printer is available or not through Air_Printer.')]};
		}
		push @{$lines[1]->{head}}, { name => "delete_printer", attributes => [ label => main::__('delete'), help => main::__('Printer Delete.')]};
	}

	foreach my $printer (sort (keys %{$printers})) {
		next if ( $printer eq "DEFAULT" );
		my $defs       = ( $printer eq $defaultp ? "*" : "" );
		my $color      = ( $printers->{$printer}->{State} eq "Stopped" ? "red" : "green" );
		my $enab_disab = ( $printers->{$printer}->{State} eq "Stopped" ? "enable" : "disable" );

		my @line = ($printer);
		push @line, { name => 'printer', value => $defs.$printer, "attributes" => [ type => "label", style => "color:".$color.";width:150px" ] };
		push @line, { name => 'description', value => $printers->{$printer}->{Info},  "attributes" => [ type => "label", style => "color:".$color.";width:200px" ] };
		push @line, { name => 'location'   , value => $printers->{$printer}->{Location}, "attributes" => [ type => "label", style => "color:".$color.";width:150px" ] };
		if ($printers->{$printer}->{NRJ} > 0){
			push @line, { jobs_waiting => $printers->{$printer}->{NRJ}};
		}else{
			push @line, { name => 'jobs_waiting'   , value => $printers->{$printer}->{NRJ}, "attributes" => [ type => "label", style => "color:".$color.";width:150px" ] };
		}
		push @line, { enable_disable => main::__("$enab_disab") };
		push @line, { reset_printer => main::__('reset') };
		if( $role =~ /^sysadmins/ ){
			my $install_printer_driver = get_install_printer_driver($printer);
			push @line, { install_driver => main::__("$install_printer_driver") };
			my $flag = $this->get_school_config("SCHOOL_ENABLE_AVAHI_PRINTER_CONFIG");
			if($flag eq "yes"){
				if(-e "/etc/avahi/services/AirPrint-$printer.service"){
					push @line, { dis_air_print => main::__("disable") };
				}else{
					push @line, { en_air_print => main::__('enable') };
				}
			}
			push @line, { delete_printer => main::__('delete') };
		}
		push @lines, { line => \@line};
	}

	if( ($reply->{warning}) and (scalar(@lines) > 1) ){
		return
		[
		   { NOTICE => "$reply->{warning}"},
		   { table  =>  \@lines },
		   { action => "cancel" },
		   { name => 'webaction', value => 'https://printserver:631/admin?OP=add-printer', attributes => [ type => 'button', label => 'new_printer', target => '_blank' ] },
		   { action => "adm_trusts" },
		   { action => "rooms" }
		];
        }

	if( scalar(@lines) > 1)
	{
		return 
		[
		   { table  =>  \@lines },
		   { action => "cancel" },
		   { name => 'webaction', value => 'https://printserver:631/admin?OP=add-printer', attributes => [ type => 'button', label => 'new_printer', target => '_blank' ] },
		   { action => "adm_trusts" },
		   { action => "rooms" }
		];
	}
	else
	{
		return
		{
			TYPE   => 'NOTICE',
			NOTICE => 'There are no printer configured.'
		}
	}
}

sub jobs_waiting
{
	my $this 	= shift;
	my $reply	= shift;
	my $printer	=$reply->{line};
	my @lines       = ('jobs');

	# Get Job List
	my $JOBS = "";
	if( $printer ) {
		my $ALLJOBS = {};
		my $ret = $this->execute('lpq -a');
		foreach my $i (split /\n/, $ret) {
			my @line = (split /\s+/,$i);
			$ALLJOBS->{$line[2]}->{owner} = $line[1];
			$ALLJOBS->{$line[2]}->{file}  = $line[3];
			$ALLJOBS->{$line[2]}->{size}  = $line[4].' '.$line[5];
		}
		$ret = $this->execute("lpstat -P $printer");
		my $color = "";
		foreach my $i (split /\n/, $ret) {
			my @line = (split /\s+/,$i);
			$line[0] =~ /(.*)-(\d+)/;
			my $jobid   = $2;
			my $time    = "$line[6] $line[5] $line[4] $line[7]";
			push @lines, { line => [ $jobid , 
			{ name => 'ID', value => $jobid,  "attributes" => [ type => "label" ], style => "color:".$color.";width:150px" }, 
			{ name => 'owner'   , value => $ALLJOBS->{$jobid}->{owner}, "attributes" => [ type => "label", style => "color:".$color.";width:150px" ] }, 
			{ name => 'file'    , value => $ALLJOBS->{$jobid}->{file},  "attributes" => [ type => "label", style => "color:".$color.";width:150px" ] }, 
			{ name => 'size'    , value => $ALLJOBS->{$jobid}->{size},  "attributes" => [ type => "label", style => "color:".$color.";width:150px" ] }, 
			{ name => 'time'    , value => $time,  "attributes" => [ type => "label", style => "color:".$color.";width:150px" ] }, 
			{ name => 'delete'  , value => 0, "attributes" => [ type => "boolean" ] }
			]}; 
		}
	}
	if( scalar(@lines) > 1)
	{
		return 
		[  
		{ NOTICE => sprintf( main::__('Print Job Overview: '.$printer)) },
		{ table  =>  \@lines },
		{ action => "cancel" }, 
		{ name => 'action'  , value => "delete_jobs", "attributes" => [ label => "apply" ] }
		];
	}
	else { return $this->default(); }
}

sub delete_jobs
{
        my $this   = shift;
        my $reply  = shift;
        my $j      = $reply->{jobs};
        my %jobs   = %$j;

        foreach my $id (keys %jobs) {
                if ($jobs{$id}->{delete} eq '1') {
                `lprm $id`
                }
        }
	return $this->default();

}

sub enable_disable
{
	my $this 	= shift;
	my $reply	= shift;
	my $printers	= $this->get_printers();
	my $printer	= $reply->{line};
	if ( $printers->{$printer}->{State} eq "Stopped" ) {
		`/usr/sbin/cupsenable $printer`;
	} else {
		`/usr/sbin/cupsdisable $printer`;
	}
	return $this->default();
}

sub reset_printer
{
	my $this 	= shift;
	my $reply	= shift;
	my $printer	= $reply->{line};
	$this->execute("/usr/sbin/cupsenable -c $printer");
	return $this->default();
}

sub rooms
{
        my $this        = shift;
        my $reply       = shift;
        my $printers    = $this->get_printers();
        my $defaultp    = $printers->{DEFAULT};
        my @lines       = ('rooms');
        my $tmp         = $this->get_rooms('all');
        my %rooms       = ();

        my @table       = ('room',{ head => [ 'room', 'default_printer','available_printer' ] } );
        foreach my $dn (sort keys %{$tmp})
        {
                $rooms{$tmp->{$dn}->{"description"}->[0]} = $dn;
        }

        my $current_page;
        my $rooms_per_page = 3;
        my $count = 0;
        my $total_rooms = keys(%rooms);
        my $page_number = $total_rooms / $rooms_per_page;
        if( exists($reply->{current_page}) ){
                $current_page = $reply->{current_page};
        }else{
                $current_page = 1;
        }

        my $pagelinemax = $current_page * $rooms_per_page;
        my $pagelinemin =$pagelinemax - $rooms_per_page;

        foreach my $room (sort keys %rooms) {
                if( ($count < $pagelinemax) and ($count >= $pagelinemin) ){
                        my @printername;
                        my @ap = ();
                        foreach my $pn (sort (keys %{$printers})) {
                                push @printername, $pn;
                        }

                        my $dprinter =  $this->get_vendor_object($rooms{$room},'EXTIS','DEFAULT_PRINTER');
			if( !$dprinter->[0] ){
				$dprinter->[0] = '---'; 
			}
                        push @ap, @printername;
                        push @ap, '---DEFAULTS---';
                        my $aprinters = $this->get_vendor_object($rooms{$room},'EXTIS','AVAILABLE_PRINTER');
                        my @aprint = split ('\n',$aprinters->[0]);
                        foreach my $aprinter ( @aprint ){
                                push @ap, $aprinter;
                        }

			push @printername, '---';

                        push @table, { line => [ $room,
                                        { name => 'room_list', value  => $room, attributes => [ type => 'label', style => "width:150px" ] },
                                        { name => 'dprinter', value => [ @printername, '---DEFAULTS---', $dprinter->[0] ], attributes => [type => "popup"] },
                                        { aprinter => \@ap},
                                        { name => 'dn', value => $rooms{$room}, attributes => [ type => "hidden"] }
                        ]};
                }
                $count++;
        }


	my @r = ();
	push @r, { subtitle => 'Manage Standard Printer of Rooms' };
	push @r, { table    => \@table };
	push @r, { current_page => $current_page };
	push @r, { page_number => $page_number };
	push @r, { rightaction   => 'cancel' };
	push @r, { name => 'rightaction', value => 'set_rooms', attributes => [ label => 'apply' ] };
	@r = $this->addturner(\@r);

        return \@r;
}

sub addturner
{
	my $this = shift;
	my $r = shift;
	my @ret = @$r;
	my $currentpage;
	my $pagenumber;

	for(my $i=0; $i < scalar(@ret); $i++){
		if ( exists($ret[$i]->{current_page}) ){
			$currentpage = $ret[$i]->{current_page};
		}
		if ( exists($ret[$i]->{page_number}) ){
                        $pagenumber = $ret[$i]->{page_number};
                }
	}

	if($currentpage == 1 ){
		push @ret, { action => 'next' };
		push @ret, { action => 'lastpage' };
        }elsif($currentpage == $pagenumber){
                push @ret, { action => 'firstpage' };
                push @ret, { action => 'back'  };
        }else{
                push @ret, { action => 'firstpage' };
                push @ret, { action => 'back'  };
                push @ret, { action => 'next' };
                push @ret, { action => 'lastpage' };
        }	
	return @ret;
}
	
sub next
{
	my $this = shift;
	my $reply =shift;
	if( $reply->{current_page} <  $reply->{page_number} ){
		$reply->{current_page} ++;
	}
	$this->rooms($reply);
}

sub back
{
	my $this = shift;
        my $reply = shift;
	if ($reply->{current_page} > 1){
        	$reply->{current_page} --;
	}
        $this->rooms($reply);
}

sub firstpage
{
	my $this = shift;
        my $reply =shift;
        $reply->{current_page} = 1;
        $this->rooms($reply);
}

sub lastpage
{
        my $this = shift;
        my $reply =shift;
        $reply->{current_page} = $reply->{page_number};
        $this->rooms($reply);
}

sub set_rooms
{
	my $this 	= shift;
	my $reply	= shift;
	my $printers    = $this->get_printers();
	
	foreach my $r ( keys %{$reply->{room}} ){
                        my @apr;
                        my @aprint = split ('\n',$reply->{room}->{$r}->{aprinter});
                        foreach my $aprinter ( @aprint ){
                                push @apr, $aprinter;
                        }

			if( (defined $reply->{room}->{$r}->{dprinter}) and ($reply->{room}->{$r}->{dprinter} ne '---') ){
                                $this->create_vendor_object($reply->{room}->{$r}->{dn},'EXTIS','DEFAULT_PRINTER',$reply->{room}->{$r}->{dprinter});
                        }else{
                                $this->delete_vendor_object($reply->{room}->{$r}->{dn},'EXTIS','DEFAULT_PRINTER');
                        }

	                if( (defined $reply->{room}->{$r}->{aprinter}) and ($reply->{room}->{$r}->{aprinter} ne '') ) {
	                        $this->create_vendor_object($reply->{room}->{$r}->{dn},'EXTIS','AVAILABLE_PRINTER',$reply->{room}->{$r}->{aprinter});
	                }else{
	                        $this->delete_vendor_object($reply->{room}->{$r}->{dn},'EXTIS','AVAILABLE_PRINTER');
        	        }
        }

	$this->rooms($reply);
}

sub adm_trusts
{
	my $this 	= shift;
	my $reply	= shift;
	my $printers	= $this->get_printers();
	my $defaultp	= $printers->{DEFAULT};
	my @lines       = ('printers');

	foreach my $printer (sort (keys %{$printers})) {
		next if ( $printer eq "DEFAULT" );
		my $defs       = ( $printer eq $defaultp ? "*" : "" );
		my $color      = ( $printers->{$printer}->{State} eq "Stopped" ? "red" : "green" );
		my $enab_disab = ( $printers->{$printer}->{State} eq "Stopped" ? "enable" : "disable" );

		my $per_user_quota = $printers->{$printer}->{PageLimit};
		my $quota_period   = $printers->{$printer}->{QuotaPeriod} / 86400;
		my ( $allowed_user, $allowed_group, $denied_user, $denied_group );
		my ( @allowed_users, @allowed_groups, @denied_users, @denied_groups );
		foreach ( split /,/, $printers->{$printer}->{AllowUser} ){
			if( /^\@(.*)/ ){
			 push @allowed_groups, $1 ;
			} else {
			 push @allowed_users, $_ ;
			}
		}
		foreach ( split /,/, $printers->{$printer}->{DenyUser} ){
			if( /^\@(.*)/ ){
			 push @denied_groups, $1 ;
			} else {
			 push @denied_users, $_ ;
			}
		}
		$allowed_user  = join( '<br>',@allowed_users );
		$allowed_group = join( '<br>',@allowed_groups );
		$denied_user   = join( '<br>',@denied_users );
		$denied_group  = join( '<br>',@denied_groups );

		my $allow_deny_deff;
                if(exists $printers->{$printer}->{AllowUser}){
                        $allow_deny_deff = 'allow';
                }elsif(exists $printers->{$printer}->{DenyUser}){
                        $allow_deny_deff = 'deny';
                }

		push @lines, { line => [ $printer , 
		{ setup_trusts => $defs.$printer } , 
		{ name => 'allow_or_deny', value => [ 'allow', 'deny', '---DEFAULTS---', "$allow_deny_deff" ], attributes => [type => 'translatedpopup'] },
		{ name => 'allowed_user', value => $allowed_user,  "attributes" => [ type => "label", style => "color:green;width:150px" ] }, 
		{ name => 'allowed_group', value => $allowed_group,  "attributes" => [ type => "label", style => "color:green;width:150px" ] }, 
		{ name => 'denied_user', value => $denied_user,  "attributes" => [ type => "label", style => "color:red;width:150px" ] }, 
		{ name => 'denied_group', value => $denied_group,  "attributes" => [ type => "label", style => "color:red;width:150px" ] }, 
		{ name => 'per_user_quota', value => $per_user_quota,  "attributes" => [ type => "label", style => "color:;width:100px" ] }, 
		{ name => 'quota_period', value => $quota_period,  "attributes" => [ type => "label", style => "color:;width:100px" ] } 
		]}; 
	}
	if( scalar(@lines) > 1)
	{
		return 
		[  { subtitle => 'adm_trust' },
		   { table  =>  \@lines }
		];
	}

}

sub setup_trusts
{
	my $this 	= shift;
	my $reply	= shift;
	my $printer	=$reply->{line};
	my @lines       = ('trusts');
	my $printers	= $this->get_printers();
	my $per_user_quota = $printers->{$printer}->{PageLimit};
	my $quota_period   = $printers->{$printer}->{QuotaPeriod} / 86400;

	if(! $reply->{printers}->{$printer}->{allow_or_deny}) {
		return {
			TYPE   => 'NOTICE',
			NOTICE => 'Please select a control type: allow or deny'
		};
		
	}

        my $name        = '*';
        my @role        = ();
        my @group       = ();
        my @class       = ();
        my @users       = ();
        my @dusers      = ();
        my $user        = $this->search_users($name,\@class,\@group,\@role);
	my ($roles, $classes, $workgroups) = $this->get_school_groups_to_search();
	my @groups =(@$roles, @$classes, @$workgroups); 
	my @dgroups =(@$roles, @$classes, @$workgroups); 

        foreach my $dn ( sort keys %{$user} )
        {
                push @users , [ 
                $dn, 
                $user->{$dn}->{uid}->[0]
                #.' '.$user->{$dn}->{cn}->[0]
                #.' ('.$user->{$dn}->{description}->[0].')' 
                ];
        }

        foreach my $dn ( sort keys %{$user} )
        {
                push @dusers , [ 
                $dn, 
                $user->{$dn}->{uid}->[0]
                #.' '.$user->{$dn}->{cn}->[0]
                #.' ('.$user->{$dn}->{description}->[0].')' 
                ];
        }
	push @groups, [ '---DEFAULTS---' ];
	push @users, [ '---DEFAULTS---' ];
	foreach( split /,/,$printers->{$printer}->{AllowUser})
	{
		if( /^\@(.*)/ ){
			push @groups, [ $this->get_group_dn($1) ] ;
		} else {
			push @users, [ $this->get_user_dn($_) ];
		}
	}
	push @dusers, [ '---DEFAULTS---' ];
	push @dgroups, [ '---DEFAULTS---' ];
	foreach( split /,/,$printers->{$printer}->{DenyUser})
	{
		if( /^\@(.*)/ ){
			push @dgroups, [ $this->get_group_dn($1) ];
		} else {
			push @dusers, [ $this->get_user_dn($_) ];
		}
	}

	if($reply->{printers}->{$printer}->{allow_or_deny} eq 'deny'){
                push @lines, { line => [ $printer ,
                                        { denied_user    => \@dusers },
                                        { denied_group   => \@dgroups },
                                ]};
        }
        elsif($reply->{printers}->{$printer}->{allow_or_deny} eq 'allow'){
                push @lines, { line => [ $printer ,
                                        { allowed_user   => \@users },
                                        { allowed_group  => \@groups },
                                ]};
        }

	my $setup_trust = main::__('Setup trusts for printer: ')." ".$printer;
	my $setup_quota = main::__('Setup quota for printer: ')." ".$printer;
	
	return 
	[  
		{ notranslate_label     => $setup_trust},
		{ table			=>  \@lines },
		{ notranslate_label     => $setup_quota},
		{ per_user_quota=> $per_user_quota },
		{ quota_period	=>   $quota_period },
		{ name          => 'allow_or_deny', value => $reply->{printers}->{$printer}->{allow_or_deny}, attributes => [type => "hidden"] },
		{ action	=> "cancel" }, 
		{ name		=> 'action'  , value => "apply_trusts", "attributes" => [ label => "apply" ] }
	];

}

sub apply_trusts
{
	my $this 	= shift;
	my $reply	= shift;

	my $pr		= $reply->{trusts};
	my $printer	= '';
	my @allowed	= ();
	my @denied	= ();
	my $prconf	= "";
	foreach my $p (keys %$pr) { $printer = $p };
	my $quota	= $reply->{per_user_quota};
	my $quotap	= $reply->{quota_period};

	my $command = "lpadmin -p $printer ";
        if($reply->{allow_or_deny} eq 'allow'){
		foreach (split /\n/, $pr->{$printer}->{allowed_user}) {
			if (/uid=(.*),/) {
				my @a = split ',', $1;
				push @allowed, $a[0];
			}
		}
		foreach (split /\n/, $pr->{$printer}->{allowed_group}) {
			if (/cn=(.*),/) {
				my @a = split ',', $1;
				push @allowed, '@'.$a[0];
			}
		}

		if( scalar(@allowed) > 0 ) {
	                $command .= "-u allow:".join(",",@allowed)." ";
	        }
	        else
	        {
	                $command .= "-u allow:all ";
	        }
	}
        elsif($reply->{allow_or_deny} eq 'deny'){
		foreach (split /\n/, $pr->{$printer}->{denied_user}) {
			if (/uid=(.*),/) {
				my @a = split ',', $1;
				push @denied, $a[0];
			}
		}
		foreach (split /\n/, $pr->{$printer}->{denied_group}) {
			if (/cn=(.*),/) {
				my @a = split ',', $1;
				push @denied, '@'.$a[0];
			}
		}

		if( scalar(@denied) > 0 ) {
			$command .= " -u deny:".join(",",@denied)." ";
		}
#		else
#		{
#		    $command .= "-u deny:none ";
#		}
	}

	if(defined $quotap && defined $quota) {
		$quotap=$quotap*86400;
#		$command .= "-o job-page-limit=$quota -o job-quota-period=$quotap";
	}
	$this->execute($command);

	if( $this->{PRINTSERVER_LOCAL} )
	{	$prconf = `cat /etc/cups/printers.conf`;}
	else
	{	$prconf = `ssh printserver cat /etc/cups/printers.conf`;}


	my @lines = split /\n/, $prconf;
	$prconf = '';
	my $p = '';
	foreach my $line (@lines) {
		# Comment
		if( $line =~ /^#/ ) {
			$prconf .= $line."\n";
			next;
		}
		# Default Printer
		if( $line =~ /<DefaultPrinter\s+(.*)>/ ) {
			$p = $1;
			$prconf .= $line."\n";
			next;
		}
		# Printer
		if( $line =~ /<Printer (.*)>/ ) {
			$p = $1;
			$prconf .= $line."\n";
		}
		# End of Printer Section
		if( $line =~ /<\/Printer>/ ) {
			$prconf .= $line."\n";
			next;
		}
		if( $line =~ /^(\w+)\s+(.*)$/) {
			if( $p eq $printer and $1 eq 'PageLimit') {
				$line = 'PageLimit '.$quota;
			}
			if( $p eq $printer and $1 eq 'QuotaPeriod') {
				$line = 'QuotaPeriod '.$quotap;
			}
			$prconf .= $line."\n";
		}
	}

	open (PRCONF, '>/etc/cups/printers.conf.temp');
	print PRCONF $prconf;
	close (PRCONF);
	if( $this->{PRINTSERVER_LOCAL} ) {
		system("cp /etc/cups/printers.conf.temp /etc/cups/printers.conf");
		$this->rc("cups","restart");
	}
	else
	{
		system("scp /etc/cups/printers.conf.temp printserver:/etc/cups/printers.conf");
		system("ssh printserver 'rccups restart'");
	}
	return $this->adm_trusts($reply);

}

sub execute
{
        my $this        = shift;
        my $command     = shift;
        my $ret         = '';
        if( $this->{PRINTSERVER_LOCAL} ) {
                $ret=`$command`;
        }
        else {
                $ret=`ssh printserver '$command'`;
        }
        return $ret;
}

sub delete_printer
{
	my $this  = shift;
	my $reply = shift;
	my $printer_name = $reply->{line};
	my $admin_pass = main::GetSessionValue('userpassword');
	my $admin_user = main::GetSessionValue('username');
	my $tmp        = $this->get_rooms('all');

	# Default und Sonstige Drucker loschen
	foreach my $room_dn (sort keys %{$tmp}){
		my $dprinter =  $this->get_vendor_object($room_dn,'EXTIS','DEFAULT_PRINTER');
		if( $dprinter->[0] and $dprinter->[0] eq $printer_name ){
			$this->delete_vendor_object($room_dn,'EXTIS','DEFAULT_PRINTER');
		}
		my $aprinters = $this->get_vendor_object($room_dn,'EXTIS','AVAILABLE_PRINTER');
		my @aprint = split ('\n',$aprinters->[0]);
		if( scalar(@aprint) ge 1 ){
			my $prin = '';
			my $flg = 0;
			foreach my $aprinter ( @aprint ){
				if( "$aprinter" eq "$printer_name" ){
					$flg = 1;
				}else{
					$prin .= $aprinter."\n"; 	
				}
			}
			if( $flg ){
				$this->delete_vendor_object($room_dn,'EXTIS','AVAILABLE_PRINTER');
				$this->create_vendor_object($room_dn,'EXTIS','AVAILABLE_PRINTER',$prin);
			}
		}
		
	}	

	# drucker treiber deactivieren
	my $install_printer_driver = get_install_printer_driver("$printer_name");
	if( $install_printer_driver eq 'active' ){
		system("rpcclient -U$admin_user%$admin_pass -c 'setdriver \"$printer_name\" \" \"' printserver");
		system("rpcclient -U$admin_user%$admin_pass -c 'deldriverex \"$printer_name\" ' printserver");
		my $del_ppd_file = $printer_name.".ppd";
		system("rm /var/lib/samba/drivers/x64/$del_ppd_file");
		system("rm /var/lib/samba/drivers/x64/3/$del_ppd_file");
		system("rm /var/lib/samba/drivers/W32X86/$del_ppd_file");
		system("rm /var/lib/samba/drivers/W32X86/3/$del_ppd_file");
		system("rcsmb reload");
	}
	$install_printer_driver = get_install_printer_driver("$printer_name");
	if( $install_printer_driver eq 'active' ){
		$reply->{warning} .= main::__('Failed the printer Windows-Driver deactivation.');
		$reply->{warning} .= "<BR>".main::__('Failed to delete printer.');
		return $this->default($reply);
	}else{
		system("lpadmin -x $printer_name");
		
	}
	system("rcsmb reload");

	if( !exists($reply->{warning}) ){
		$reply->{warning} = main::__('The printer is deleted successfully.');
	}
	return $this->default($reply);
}

sub install_driver
{
	my $this  = shift;
	my $reply = shift;
	my $printer_name = $reply->{line};
	my $admin_pass = main::GetSessionValue('userpassword');
	my $admin_user = main::GetSessionValue('username');
	my $install_printer_driver = get_install_printer_driver("$printer_name");
	system('rcsmb reload');
	if($install_printer_driver eq 'inactive'){
		if( !(-e "/var/lib/samba/drivers/W32X86/3") ){
			my $cmd = "mkdir /var/lib/samba/drivers/W32X86/3; chmod 777 /var/lib/samba/drivers/W32X86/3/;";
			$cmd .= 'cp /usr/share/cups/drivers/* /var/lib/samba/drivers/W32X86/; cp /usr/share/cups/drivers/* /var/lib/samba/drivers/W32X86/3/;';
			$cmd .= 'cp /etc/cups/ppd/'.$printer_name.'.ppd /var/lib/samba/drivers/W32X86/; cp /etc/cups/ppd/'.$printer_name.'.ppd /var/lib/samba/drivers/W32X86/3/;';
			$cmd .= 'chown -R admin:ntadmin /var/lib/samba/drivers/W32X86/*;';
			system("$cmd");
		}else{
			my $cmd = 'cp /etc/cups/ppd/'.$printer_name.'.ppd /var/lib/samba/drivers/W32X86/; cp /etc/cups/ppd/'.$printer_name.'.ppd /var/lib/samba/drivers/W32X86/3/;';
			$cmd .= 'chown -R admin:ntadmin /var/lib/samba/drivers/W32X86/*;';
			system("$cmd");
		}

		if( !(-e "/var/lib/samba/drivers/x64/3") ){
			my $cmd = "mkdir /var/lib/samba/drivers/x64/3; chmod 777 /var/lib/samba/drivers/x64/3/;";
			$cmd .= 'cp /usr/share/cups/drivers/x64/* /var/lib/samba/drivers/x64/; cp /usr/share/cups/drivers/x64/* /var/lib/samba/drivers/x64/3/;';
			$cmd .= 'cp /etc/cups/ppd/'.$printer_name.'.ppd /var/lib/samba/drivers/x64/; cp /etc/cups/ppd/'.$printer_name.'.ppd /var/lib/samba/drivers/x64/3/; ';
			$cmd .= 'chown -R admin:ntadmin /var/lib/samba/drivers/x64/*;';
			system("$cmd");
		}else{
			my $cmd = 'cp /etc/cups/ppd/'.$printer_name.'.ppd /var/lib/samba/drivers/x64/; cp /etc/cups/ppd/'.$printer_name.'.ppd /var/lib/samba/drivers/x64/3/; ';
			$cmd .= 'chown -R admin:ntadmin /var/lib/samba/drivers/x64/*;';
			system("$cmd");
		}

		system('rcsmb reload');
		cmd_pipe('at now', "cupsaddsmb -H printserver -U $admin_user%$admin_pass -v $printer_name");

		my $prt = $this->check_pid_cupsaddsmb();
		if( $prt ){
			return [
				{ NOTICE => sprintf( main::__('The activation of windows printer driver is in progress for printer "%s". Please, try it later.'), $prt ) }
			]
		}else{
			return $this->default();
		}
	}elsif( $install_printer_driver eq 'active' ){
		system("rpcclient -U$admin_user%$admin_pass -c 'setdriver \"$printer_name\" \" \"' printserver");
		system("rpcclient -U$admin_user%$admin_pass -c 'deldriverex \"$printer_name\" ' printserver");
		my $del_ppd_file = $printer_name.".ppd";
		system("rm /var/lib/samba/drivers/x64/$del_ppd_file");
		system("rm /var/lib/samba/drivers/x64/3/$del_ppd_file");
		system("rm /var/lib/samba/drivers/W32X86/$del_ppd_file");
		system("rm /var/lib/samba/drivers/W32X86/3/$del_ppd_file");
		system("rcsmb reload");

		my $install_printer_driver = get_install_printer_driver("$printer_name");
		if($install_printer_driver eq 'inactive'){
			return $this->default();
		}else{
			$reply->{warning} = sprintf( main::__('Deleting the printer driver to "%s" printer  was unsucessful !!!'), $printer_name );
			return $this->default($reply);
		}
	}
}

sub get_install_printer_driver
{
        my $printer_name = shift;
	my $install_driver;
	my $admin_pass = main::GetSessionValue('userpassword');
	my $admin_user = main::GetSessionValue('username');

	my $get_driver = `rpcclient -U$admin_user%$admin_pass -c 'getdriver "$printer_name"' printserver | grep "Driver Name"`;
	my $get_printer_driver = `rpcclient -U$admin_user%$admin_pass -c 'getprinter "$printer_name" 2' printserver | grep "drivername"`;

	if( $get_driver and $get_printer_driver ){
		$install_driver = 'active';
	}else{
		$install_driver = 'inactive';
	}

	return $install_driver;
}

sub en_air_print
{
	my $this  = shift;
	my $reply = shift;
	my $printer     = $reply->{line};
	my $printers    = $this->get_printers();
	my $air_print_tmp = `cat /usr/share/oss/templates/air_print_tmp`;

	$air_print_tmp =~ s/#printer_name#/$printer/g;
	$air_print_tmp =~ s/#location#/$printers->{$printer}->{Location}/g;
	$air_print_tmp =~ s/#make_model#/$printers->{$printer}->{MakeModel}/g;
	my $printer_type = sprintf("%x", $printers->{$printer}->{Type});
	$air_print_tmp =~ s/#printer_type#/$printer_type/g;
	my $printer_state = '';
	if($printers->{$printer}->{State} eq "Idle"){
		$printer_state = 3;
	}elsif($printers->{$printer}->{State} eq "Stopped"){
		$printer_state = 5;
	}
	$air_print_tmp =~ s/#printer_state#/$printer_state/g;

	write_file("/etc/avahi/services/AirPrint-$printer.service",$air_print_tmp);
	system("rcavahi-daemon restart");

	return $this->default();
}

sub dis_air_print
{
	my $this  = shift;
	my $reply = shift;
	my $printer     = $reply->{line};

	system("rm /etc/avahi/services/AirPrint-$printer.service");
	system("rcavahi-daemon restart");

	return $this->default();
}

sub check_pid_cupsaddsmb
{
	my $this  = shift;
	my $value = cmd_pipe("ps ax | grep cupsaddsmb | awk '{if( \$6 ~ /^-H/){ print \$12}}'");
	return $value;
}

1;
