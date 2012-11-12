# OSS Printer Management Module for Users
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ManagePrinterQueue; 

use strict;
use oss_base;
use oss_utils;
use Data::Dumper;
#use MIME::Base64;
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
		"jobs_waiting",
		"reset_printer",
		"delete_jobs"
        ];
}

sub getCapabilities
{
        return [
                { title        => 'Printer Queue Administration' },
                { type         => 'command' },
#                { allowedRole  => 'root' },
#                { allowedRole  => 'sysadmins' },
                { allowedRole  => 'teachers' },
#                { allowedRole  => 'teachers,sysadmins' },
                { allowedRole  => 'students' },
                { category     => 'System' },
		{ order        => 20 },
		{ variable     => [ 'printer',       [type => 'action'] ]}, 
		{ variable     => [ 'description ',  [type => 'label'] ]}, 
		{ variable     => [ 'location',      [type => 'label'] ]}, 
		{ variable     => [ 'jobs_waiting',  [type => 'action'] ]},
		{ variable     => [ 'reset_printer', [type => 'action'] ]}, 
		{ variable     => [ 'delete_jobs',   [type => 'action'] ]}
	];
}


sub default
{
        my $this   = shift;
        my $reply  = shift;
        my $role   = main::GetSessionValue('role');
        if( $role =~ /^teachers/ )
        {
                $this->show_printers($reply);
        }
        elsif( $role =~ /^students/ )
        {
                $this->show_jobs($reply);
        }
}



sub show_printers
{
	my $this 	= shift;
	my $reply	= shift;
	my $printers	= $this->get_printers();
	my $defaultp	= $printers->{DEFAULT};
	my @ret = ();
	my $arrays   = {};

	push @{$arrays->{printers}} , "printers";
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
                push @line, { reset_printer => 'reset' };
                push @{$arrays->{printers}}, { line => \@line};
        }
	if( scalar(@{$arrays->{printers}}) > 1){
		push @ret , { label => "Printers" };
		push @ret , { table =>  $arrays->{printers} };
	}
	else
	{
		push @ret , { NOTICE => 'There are no printer configured.' };
	}

	my $quota = $this->get_free_quota();
	push @{$arrays->{quota}}, "quota";
	push @{$arrays->{quota}}, {head => ['printer', 'Default Room', 'Available Room', 'Free PageQuota', 'Used PageQuota', 'per_user_quota', 'quota_period']};
	foreach my $printer (sort (keys %{$quota})) {
		push @{$arrays->{quota}}, { line => [ $printer ,
			{name => 'printer_name', value => $printer,  "attributes" => [ type => 'label',style => "width:100px" ]},
			{name => 'default_printer_in_room', value => "$quota->{$printer}->{default_printer_in_room}", attributes => [ type => 'label', style => "width:100px" ]},
			{name => 'available_printer_in_room', value => "$quota->{$printer}->{available_printer_in_room}", attributes => [ type => 'label', style => "width:100px" ]},
			{name => 'free_pagequota'  , value => "$quota->{$printer}->{free_pagequota}", "attributes" => [ type => "label", style => "width:100px" ]},
			{name => 'used_pagequota', value => "$quota->{$printer}->{used_pagequota}", "attributes" => [ type => "label", style => "width:100px" ]},
			{name => 'user_pagequota', value => "$quota->{$printer}->{user_pagequota}", "attributes" => [ type => "label", style => "width:100px" ]},
			{name => 'quota_period', value => "$quota->{$printer}->{quota_period}", "attributes" => [ type => "label", style => "width:100px" ]},
		]};
	}
	if( scalar(@{$arrays->{quota}}) > 1){
		push @ret , { label => "Your Printer quotes" };
                push @ret , { table =>  $arrays->{quota} };
        }               
        else            
        {
                push @ret , { NOTICE => 'You don\'t have access to any printers !' };
        }

	return \@ret;
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
		my $ret = $this->execute("lpq -a");
		foreach my $i (split /\n/, $ret) {
			my @line = (split /\s+/,$i);
			$ALLJOBS->{$line[2]}->{owner} = $line[1];
			$ALLJOBS->{$line[2]}->{file}  = $line[3];
			$ALLJOBS->{$line[2]}->{size}  = $line[4].' '.$line[5];
		}
		$ret = $this->execute("lpstat -o");
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

sub show_jobs
{
	my $this 	= shift;
	my $reply	= shift;
	my $uid     = get_name_of_dn($this->{aDN});
	my @ret = ();
	my $arrays   = {};

	my $role   = main::GetSessionValue('role');
	if( $role =~ /^students/ ){
		my $quota = $this->get_free_quota();
		push @{$arrays->{quota}} , "quota";
		push @{$arrays->{quota}}, {head => ['printer', 'Default Room', 'Available Room', 'Free PageQuota', 'Used PageQuota', 'per_user_quota', 'quota_period']};
		foreach my $printer (sort (keys %{$quota})) {
			push @{$arrays->{quota}}, { line => [ $printer ,
				{name => 'printer_name', value => $printer,  "attributes" => [ type => 'label',style => "width:100px" ]},
				{name => 'default_printer_in_room', value => "$quota->{$printer}->{default_printer_in_room}", attributes => [ type => 'label', style => "width:100px" ]},
				{name => 'available_printer_in_room', value => "$quota->{$printer}->{available_printer_in_room}", attributes => [ type => 'label', style => "width:100px" ]},
				{name => 'free_pagequota'  , value => "$quota->{$printer}->{free_pagequota}", "attributes" => [ type => "label", style => "width:100px" ]},
				{name => 'used_pagequota', value => "$quota->{$printer}->{used_pagequota}", "attributes" => [ type => "label", style => "width:100px" ]},
				{name => 'user_pagequota', value => "$quota->{$printer}->{user_pagequota}", "attributes" => [ type => "label", style => "width:100px" ]},
				{name => 'quota_period', value => "$quota->{$printer}->{quota_period}", "attributes" => [ type => "label", style => "width:100px" ]},
			]};
		}
		if( scalar(@{$arrays->{quota}}) > 1){
			push @ret , { label => "Your Printer quotes" };
			push @ret , { table =>  $arrays->{quota} };
		}
		else
		{
			push @ret , { NOTICE => 'You don\'t have access to any printers !' };
		}
	}

	push @{$arrays->{jobs}} , "jobs";
	# Get Job List
	my $JOBS = "";
	my $ALLJOBS = {};
	my $ret = $this->execute("lpq -a");
	foreach my $i (split /\n/, $ret) {
		my @line = (split /\s+/,$i);
		$ALLJOBS->{$line[2]}->{owner} = $line[1];
		$ALLJOBS->{$line[2]}->{file}  = $line[3];
		$ALLJOBS->{$line[2]}->{size}  = $line[4].' '.$line[5];
	}
	$ret = $this->execute("lpstat -o");
	my $color = "";
	foreach my $i (split /\n/, $ret) {
		my @line = (split /\s+/,$i);
		$line[0] =~ /(.*)-(\d+)/;
		my $printer = $1;
		my $jobid   = $2;
		my $time    = "$line[6] $line[5] $line[4] $line[7]";
		if ($ALLJOBS->{$jobid}->{owner} eq $uid) {
			push @{$arrays->{jobs}}, { line => [ $jobid , 
			{ name => 'ID', value => $jobid,  "attributes" => [ type => "label" ], style => "color:".$color.";width:150px" }, 
			{ name => 'printer' , value => $printer, "attributes" => [ type => "label", style => "color:".$color.";width:150px" ] }, 
			{ name => 'owner'   , value => $ALLJOBS->{$jobid}->{owner}, "attributes" => [ type => "label", style => "color:".$color.";width:150px" ] }, 
			{ name => 'file'    , value => $ALLJOBS->{$jobid}->{file},  "attributes" => [ type => "label", style => "color:".$color.";width:150px" ] }, 
			{ name => 'size'    , value => $ALLJOBS->{$jobid}->{size},  "attributes" => [ type => "label", style => "color:".$color.";width:150px" ] }, 
			{ name => 'time'    , value => $time,  "attributes" => [ type => "label", style => "color:".$color.";width:150px" ] }, 
			{ name => 'delete'  , value => 0, "attributes" => [ type => "boolean" ] }
			]};
		} 
	}
	if( scalar(@{$arrays->{jobs}}) > 1){
		push @ret , { label => 'Print Jobs for user: '.$uid};
#		push @ret , { NOTICE => sprintf( main::__('Print Job Overview','')) };
		push @ret , { table =>  $arrays->{jobs} };
		push @ret , { action => "cancel" };
                push @ret , { name => 'action'  , value => "delete_jobs", "attributes" => [ label => "apply" ] };
	}
	else
	{
		push @ret , { NOTICE => sprintf( main::__('No Print Jobs for user: '.$uid)) }
	}

	return \@ret;
}


sub delete_jobs
{
        my $this   = shift;
        my $reply  = shift;
        my $j      = $reply->{jobs};
        my %jobs   = %$j;

        foreach my $id (keys %jobs) {
                if ($jobs{$id}->{delete} eq '1') {
			$this->execute("lprm $id");
                }
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

sub execute
{
	my $this 	= shift;
	my $command 	= shift;
	my $ret		= '';
	if( $this->{PRINTSERVER_LOCAL} ) {
		$ret=`$command`;
	}
	else {
		$ret=`ssh printserver '$command'`;
	}
	return $ret;
}

sub get_free_quota
{
	my $this   = shift;
	my $reply  = shift;
	my $role   = main::GetSessionValue('role');
	$role = uc($role);
	my $user   = main::GetSessionValue('username');
	my @printers;
	my %ret;
#print Dumper(%ret);exit;

	my $prconf;
	if( $this->{PRINTSERVER_LOCAL} )
        {       $prconf = `cat /etc/cups/printers.conf`;}
        else
        {       $prconf = `ssh printserver cat /etc/cups/printers.conf`;}
        my @prts = split /<\/Printer>/, $prconf;

	foreach my $pr (@prts){
		my $flag = 1;
		my @lines = split /\n/, $pr;
		my $print;
		if($pr =~ /^\n$/){
			$flag = 0;
		}
		foreach my $line (@lines) {
			# Printer
			if( $line =~ /<Printer (.*)>/ ) {
				$print = $1;
			}
			#DenyUser
			if($line =~ /DenyUser (.*)/){
				if($1 eq $user){
					$flag = 0;
				}
				if($1 eq "@".$role ){
					$flag = 0;
				}
			}
			#AllowUser
			if($line =~ /AllowUser (.*)/){
				if($1 ne $user){
					$flag = 0;
				}elsif($1 eq $user){
					$flag = 1;last;
				}
				if($1 ne "@".$role){
					$flag = 0;
				}elsif($1 eq "@".$role){
					$flag = 1;last;
				}
			}
		}
		if($flag eq 1){
			push @printers, $print;
		}
	}

	my $rooms = $this->get_rooms('all');
	foreach my $printer (sort @printers) {
		my $default_printer_in_room;
		my $available_printer_in_room;
		foreach my $room_dn (sort keys %{$rooms}){
			my $dprinter =  $this->get_vendor_object($room_dn,'EXTIS','DEFAULT_PRINTER');
			if( $printer eq $dprinter->[0] ){
				$default_printer_in_room .= $rooms->{$room_dn}->{description}->[0].", ";
			}
			my $aprinters = $this->get_vendor_object($room_dn,'EXTIS','AVAILABLE_PRINTER');
			my @aprint = split ('\n',$aprinters->[0]);
			my @ap;
			foreach my $aprinter ( @aprint ){
				if( $printer eq $aprinter ){
					$available_printer_in_room .= $rooms->{$room_dn}->{description}->[0].", ";
				}
			}
		}

		my $tmp = `gawk '{ if((\$1 ~ /$printer/) && (\$2 ~ /$user/)){ print \$7}}' /var/log/cups/page_log`;
		my @lines = split("\n",$tmp);
		my $used_pagequota = 0;
		foreach my $job_per_page (@lines){
			print $job_per_page." job_per_page.\n";
			$used_pagequota = $used_pagequota + $job_per_page;
		}
		my $printers      = $this->get_printers();
		my $quota_period  = $printers->{$printer}->{QuotaPeriod} / 86400;  # QuotaPeriod
		my $user_pagequota = $printers->{$printer}->{PageLimit}; #PageLimit		
		my $free_pagequota    = $user_pagequota-$used_pagequota;

		$ret{$printer}->{default_printer_in_room} = $default_printer_in_room;
		$ret{$printer}->{available_printer_in_room} = $available_printer_in_room;
		if( ($quota_period eq 0) and ($user_pagequota eq 0) ){
			$ret{$printer}->{free_pagequota} = "-";
			$ret{$printer}->{used_pagequota} = $used_pagequota;
                        $ret{$printer}->{user_pagequota} = "-";
                        $ret{$printer}->{quota_period} = "-";
			
		}else{
			$ret{$printer}->{free_pagequota} = $free_pagequota;
			$ret{$printer}->{used_pagequota} = $used_pagequota;
			$ret{$printer}->{user_pagequota} = $user_pagequota;
			$ret{$printer}->{quota_period} = $quota_period;
		}

	}

	return \%ret;
}

1;
