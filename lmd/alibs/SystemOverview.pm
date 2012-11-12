# LMD SystemOverview modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package SystemOverview;

use strict;
use oss_base;
use oss_utils;
use Data::Dumper;
use XML::Simple;
use MIME::Base64;
use Encode qw(encode decode);
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
		"refresh_page",
        ];
}

sub getCapabilities
{
        return [
                { title        => 'SystemOverview' },
                { type         => 'command' },
                { allowedRole  => 'root' },
                { allowedRole  => 'sysadmins' },
                { category     => 'System' },
                { order        => 10 },
                { variable     => [  "img"                => [ type => 'img', style => 'width:300px;background-color:#FFFFFF' ]]},
		{ variable     => [  "value"              => [ type => 'label', style => 'text-align:left;background-color:#FFFFFF' ]]},
		{ variable     => [  "name"               => [ type => 'label', style => 'width:300px;text-align:right;font-weight:bold;background-color:#FFFFFF' ]]},
                ];
}


sub default
{
        my $this        = shift;
        my $reply       = shift;
        my @ret;
	my $school_dn = $this->{SCHOOL_BASE};
	my $systemoverview_val = $this->get_vendor_object( "$school_dn", 'extis','SystemOverview');
	my %hash;

	foreach my $value (@$systemoverview_val){
		my @splt_val = split("#;#",$value);
		my $head = $splt_val[0];
		my $name_value = $splt_val[1];
		my $tmp = $splt_val[2];

		my @n_v = split("#=#",$name_value);
		$hash{$head}->{$n_v[0]}->{value} = $n_v[1]; 
		if($tmp){
			my @splt_tmp = split("#=#",$tmp);
			$hash{$head}->{$n_v[0]}->{$splt_tmp[0]} = $splt_tmp[1];
		}
	}

#--------Software-----------------------------
	my @software     = ('software');
	push @software, {head => ['', '' ]};

	#System
	if( exists($hash{software}->{system_name}->{value}) ){
		push @software, { line => [ 'system_name', { name =>  main::__('System : ') }, { value => "$hash{software}->{system_name}->{value}"} ]};
	}

	#System Version
	if( exists($hash{software}->{systemversion}->{value}) ){
		push @software, { line => [ 'systemversion',
						{ name =>  main::__('SystemVersion : ') },
						{ name => 'value', value => "$hash{software}->{systemversion}->{value}", attributes => [type => 'label', style => 'text-align:left;background-color:#FFFFFF', help => "$hash{software}->{systemversion}->{help}" ]  },
				]};
	}

	#Last Update
	if( exists($hash{software}->{lastupdate}->{value}) ){
		push @software, { line => [ 'lastupdate', { name =>  main::__('LastUpdate : ') }, { value => "$hash{software}->{lastupdate}->{value}"} ]};
	}

	#RegCode
	if( exists($hash{software}->{school_regcode}->{value}) ){
		push @software, { line => [ 'school_regcode', { name =>  main::__('Regcode : ') }, {value => "$hash{software}->{school_regcode}->{value}"}]};
	}

	#Licence-Information
	if( exists($hash{software}->{licenceinformation}->{value}) ){
		push @software, { line => [ 'licenceinformation', { name =>  main::__('LicenceInformation : ') }, { value => "$hash{software}->{licenceinformation}->{value}"} ]};
	}

	#SystemUpTime
        my $systemuptime = cmd_pipe("procinfo | awk  '{ if( \$1 == \"uptime:\") { print \$2 }}'");
        chomp $systemuptime;
        my $output_uptime = '';
        if( $systemuptime =~ /^[0-9]{1,5}d$/){
		my $days = $systemuptime;
                $days =~ s/d//;
                my $years = int($days/364);
                $days = $days-(364*$years);
                if( $years ne 0 ){
                        $output_uptime .= $years." ".main::__('years').", ";
                }

                $output_uptime .= $days." ".main::__('days').", ";
                $systemuptime = cmd_pipe("procinfo | awk  '{ if( \$1 == \"uptime:\") { print \$3 }}'");
                chomp $systemuptime;
        }
#print $systemuptime."--->systemuptime\n";exit;
        my ($time, $tmp) = split('\.', $systemuptime);
        my ( $hour, $minute, $sec ) = split(":", $time);
        if($minute =~ /^0[0-9]/){$minute =~ s/0//}
        $output_uptime .= $hour." ".main::__('hours').", ".$minute." ".main::__('minutes');
        push @software, { line => [ 'systemuptime', { name => main::__('SystemUpTime : ') }, { value => "$output_uptime"} ]};

	#MonitorProcesses
	my $monitorprocesses = '';
	my $defpract = 'active';
	my $prcolor = 'blue';
	my @rcstatus = ();
	my $mon_procs = $this->get_school_config('SCHOOL_MONITOR_SERVICES');
	my @procs = split ',', $mon_procs;
	my %activeProcesses = getActiveProcesses();
	foreach my $process (@procs){
		if( exists $activeProcesses{$process} ){
			$defpract = 'active';
		}else{
			$defpract = 'inactive';
		}
		@rcstatus = `rc$process status | grep running`;

		if( scalar(@rcstatus)>=1 ){
			$prcolor = 'blue';
			$monitorprocesses = main::__('OK');
		}else{
			if( $defpract eq 'active' ){
				$prcolor = 'red';
				$monitorprocesses = main::__('not OK').' --> <a href="/ossadmin/?application=MonitorProcesses" target="">'.main::__('MonitorProcesses').'</a>';
				last;
			}else{
				$prcolor = 'blue';
				$monitorprocesses = main::__('OK');
			}
		}
	}
	push @software, { line => [ 'monitorprocesses',
                                               { name =>  main::__('MonitorProcesses : ') },
                                               { name => 'value', value => "$monitorprocesses", attributes => [type => 'label', style => 'text-align:left;background-color:#FFFFFF;color:'.$prcolor ] },
                               ]};
	push @software, { line => [ 'aaa', { name =>  "" }, { value => ""} ]};
	push @software, { line => [ 'aaa', { name =>  "" }, { value => ""} ]};

#--------Hardware----------------------------------
        my @hardware = ('hardware');
        push @hardware, {head => ['', '' ]};

	#Processor Number 
	if( exists($hash{hardware}->{processor_number}->{value}) ){
		push @hardware, { line => [ 'processor_number', { name =>  main::__('Processor Number : ') }, { value => "$hash{hardware}->{processor_number}->{value}"} ]};
	}

	#Processor Name
	if( exists($hash{hardware}->{processor_name}->{value}) ){
		push @hardware, { line => [ 'processor_name', { name =>  main::__('Processor Name : ') }, { value => "$hash{hardware}->{processor_name}->{value}"} ]};
	}

	#Main Memory
	if( exists($hash{hardware}->{main_memory}->{value}) ){
		push @hardware, { line => [ 'main_memory', { name => main::__('MainMemory : ') }, { value => "$hash{hardware}->{main_memory}->{value}"} ]};
	}
	push @hardware, { line => [ 'aaa', { name =>  "" }, { value => ""} ]};
	push @hardware, { line => [ 'aaa', { name =>  "" }, { value => ""} ]};

#---------Domain-------------------------------
	my @domain = ('domain');
        push @domain, {head => ['', '' ]};

	#DomainName
	if( exists($hash{domain}->{domainname}->{value}) ){
		push @domain, { line => [ 'domainname', { name => main::__('DomainName : ') }, { value => "$hash{domain}->{domainname}->{value}"} ]};
	}

	#SambaDomain
	if( exists($hash{domain}->{sambadomain}->{value}) ){
		push @domain, { line => [ 'sambadomain', { name => main::__('SambaDomain : ') }, { value => "$hash{domain}->{sambadomain}->{value}"} ]};
	}

	#LDAP_base
	if( exists($hash{domain}->{ldapbaseDN}->{value}) ){
		push @domain, { line => [ 'ldapbaseDN', { name => main::__('LdapBaseDN : ') }, { value => "$hash{domain}->{ldapbaseDN}->{value}"} ]};
	}
	push @domain, { line => [ 'aaa', { name =>  "" }, { value => ""} ]};
	push @domain, { line => [ 'aaa', { name =>  "" }, { value => ""} ]};

#---------Status Processor---------------------

	my @disk_usage = ('diskusage');
        push @disk_usage, {head => ['', '' ]};
        my @images_base64;

	foreach my $img_path (sort keys %{$hash{disk_usage}}){
		my $img_file   = `base64 $img_path`;
		push @images_base64, $img_file;
        }
	my $size = scalar(@images_base64);
        my $i = 0;
        do{
                if( $images_base64[$i+2] ){
                        push @disk_usage, {line => ['dsk_usg', {img => "$images_base64[$i]"}, {img => "$images_base64[$i+1]"}, {img => "$images_base64[$i+2]"} ]};
                }elsif( $images_base64[$i+1] ){
                        push @disk_usage, {line => ['dsk_usg', {img => "$images_base64[$i]"}, {img => "$images_base64[$i+1]"} ]};
                }else{
                        push @disk_usage, {line => ['dsk_usg', {img => "$images_base64[$i]"} ]};
                }
                $i+=3;
        }while($i<$size);

	push @ret, { label => 'Software' };
	push @ret, { table => \@software };
	push @ret, { label => 'Hardware' };
	push @ret, { table => \@hardware };
	push @ret, { label => 'Domain' };
	push @ret, { table => \@domain };
	push @ret, { label => 'Status' };
	push @ret, { table => \@disk_usage };
	push @ret, { action => 'refresh_page'};

	return \@ret;
}

sub refresh_page
{
	my $this  = shift;
	cmd_pipe("/usr/share/oss/tools/make_data_systemoverview.pl");
	return $this->default();
}

sub getActiveProcesses
{
	my $runlevel = `runlevel |awk '{ print \$(NF) }'`;
	my $rl = eval (2 +$runlevel) ;
	my $r  = eval $runlevel ;
	my $args = "chkconfig -l | awk '/$r/ {print "."\$"."1, \$".$rl."}' | sed 's/$r"."://'";
	my @proc_table = `$args`;
	my %processes = ();
	foreach my $pr (@proc_table) {
		my @tproc = split " ", $pr;
		if (($tproc[1]) eq "on") {
			$processes{$tproc[0]} = $tproc[1];
		}
	}
	return (%processes);
}

1;

