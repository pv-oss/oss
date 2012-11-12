# DYN-DNS modul
# Copyright (c) 2012 EXTIS GmbH, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package DynDNSSimple;

use strict;
use oss_base;
use oss_utils;
use Data::Dumper;
use vars qw(@ISA);
@ISA = qw(oss_base);

my %ddns_services = (
  'dyndns2'       => 'www.dyndns.org',
  'easydns'       => 'www.easydns.com',
  'dnspark'       => 'www.dnspark.com',
  'zoneedit1'     => 'www.zoneedit.com',
  'dslreports1'   => 'www.dslreports.com',
  'hammernode1'   => 'www.hn.org',
  'no-ip'         => 'www.no-ip.com',
);

my %ddns_settings = (
  'dyndns2'     => {
    'login'       => '',
    'password'    => '',
    'server'      => 'members.dyndns.org:8245',
    'protocol'    => 'dyndns2',
  },
  'easydns'     => {
    'login'       => '',
    'password'    => '',
    'server'      => 'members.easydns.com',
    'protocol'    => 'easydns',
  },
  'dnspark'     => {
    'login'       => '',
    'password'    => '',
    'server'      => 'www.dnspark.com',
    'protocol'    => 'dnspark',
  },
  'zoneedit1'   => {
    'login'       => '',
    'password'    => '',
    'server'      => 'www.zoneedit.com',
    'protocol'    => 'zoneedit1',
  },
  'dslreports1' => {
    'login'       => '',
    'password'    => '',
    'server'      => 'www.dslreports.com',
    'protocol'    => 'dslreports1',
  },
  'hammernode1' => {
    'login'       => '',
    'password'    => '',
    'server'      => 'dup.hn.org',
    'protocol'    => 'hammernode1',
  },
  'no-ip' => {
    'login'       => '',
    'password'    => '',
    'server'      => 'www.no-ip.com',
    'protocol'    => 'dyndns2',
  },
);

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
		"save_global_conf",
		"new_host",
		"edit_host",
		"save_host",
		"delete_host",
		"my_cancel",
	];

}

sub getCapabilities
{
	return [
		{ title        => 'DYN-DNS' },
		{ type         => 'command' },
		{ allowedRole  => 'root' },
		{ allowedRole  => 'sysadmins' },
		{ category     => 'Network' },
		{ order        => 90 },
		{ variable     => [ "service_name",             [ type => 'action'] ] },
		{ variable     => [ "edit_service",             [ type => 'action'] ] },
		{ variable     => [ "delete_service",           [ type => 'action'] ] },
		{ variable     => [ "host_name",                [ type => 'label', style => 'width:300px;'] ] },
		{ variable     => [ "ddns_services",            [ type => 'label'] ] },
		{ variable     => [ "save_host",                [ type => 'action' ] ] },
		{ variable     => [ "edit_host",                [ type => 'action' ] ] },
		{ variable     => [ "delete_host",              [ type => 'action' ] ] },
		{ variable     => [ "my_cancel",                [ type => 'action', label => 'cancel' ] ] },
	];
}

sub default
{
	my $this  = shift;
	my $reply = shift;
	my @lines = ('hosts');
	my @ret;
	my %ddc;
	my $split_file = split_conf_file();

	if($reply->{warning}){
		push @ret, { NOTICE => "$reply->{warning}" };
	}
	if(exists($reply->{hosts_status})){
		push @ret, { NOTICE => "$reply->{hosts_status}" };
	}
	if(-e '/etc/ddclient.conf.old'){
		system('cp /etc/ddclient.conf.old /etc/ddclient.conf');
		system('rm /etc/ddclient.conf.old');
	}

	my $split_file = split_conf_file();

	push @lines, { head => [ 'host_name', 'ddns_services', 'edit', 'delete' ]};
	foreach my $ddc_service ( sort keys %{$split_file->{ddclient_conf}}){
		push @lines, { line => [ $split_file->{ddclient_conf}->{$ddc_service}->{host},
				{ host_name => $split_file->{ddclient_conf}->{$ddc_service}->{host} },
				{ ddns_services => "$ddns_services{$ddc_service}" },
				{ edit_host =>  main::__('edit')},
				{ delete_host =>  main::__('delete') },
				{ name => 'ddns_services', value => "$ddc_service", attributes => [ type => 'hidden'] },
				{ name => 'edit_h', value => "1", attributes => [ type => 'hidden'] },
			]};
	}

	if( scalar(@lines) > 2){
		push @ret, { label => main::__('The following settings exist :')};
		push @ret, { table => \@lines };
	}else{
		push @ret, { NOTICE => main::__('There are no existing settings.')};
	}

	my @global_config = split("\n",$split_file->{ddclinet_conf_head});
	push @ret, { label => 'Global configuration :'};
	foreach my $line (@global_config){
		if($line =~ /^daemon=(.*)/){
			push @ret, { name => 'daemon', value => $1, attributes => [ type => 'string', backlabel => "sec" ]};
		}
		if($line =~ /^mail-failure=(.*)/){
			push @ret, { name => 'mail_failure', value => $1, attributes => [ type => 'string']};
		}
	}

	push @ret, { action => 'save_global_conf'};
	push @ret, { action => 'new_host'};

	return \@ret;
}

sub save_global_conf
{
	my $this  = shift;
	my $reply =shift;
	my $content_head = '';

	if( !($reply->{daemon} =~ /^[0-9]{0,20}$/) ){
		$reply->{warning} = main::__("Please only use numeric characters in the \"deamon\" field");
		return $this->default($reply);
	}

	my $split_file = split_conf_file();
	my @global_config = split("\n",$split_file->{ddclinet_conf_head});
	foreach my $line (@global_config){
		if($line =~ /^daemon=(.*)/){
			$content_head .= "daemon=".$reply->{daemon}."\n";
		}
		if($line =~ /^mail-failure=(.*)/){
			$content_head .= "mail-failure=".$reply->{mail_failure}."\n";
		}elsif(($line =~ /(.*)/) and ($line !~ /^daemon=(.*)/) and ($line !~ /^mail-failure=(.*)/)){
			$content_head .= $1."\n";
		}
	}

	$split_file->{ddclinet_conf_head} = $content_head;
	$this->save_content_to_file($split_file);
	return $this->default();
}

sub new_host
{
	my $this  = shift;
	my $reply = shift;
	my @ddns = ();
	my @ret;
	my $split_file = split_conf_file();

	system("cp /etc/ddclient.conf /etc/ddclient.conf.old");

	if($reply->{warning}){
		push @ret, { NOTICE => "$reply->{warning}" };
	}

	foreach my $new_dyndns ( sort keys %ddns_services){
		if(!exists($split_file->{ddclient_conf}->{$new_dyndns})){
			push @ddns, [$new_dyndns , $ddns_services{$new_dyndns}];
		}
	}
	my $size_ddns = @ddns;
	if( !$size_ddns ){
		return [
			{ NOTICE => main::__('There are not any services left, to create new hosts !')},
			{ action => 'cancel' },
		]
	}

	foreach my $item ( @ddns ){
		if($item->[1] =~ /^www.dyndns.org/){
			push @ddns,  [ '---DEFAULTS---' ], [ "$item->[0]" ];
		}
	}

	push @ret, { subtitle => 'Create new Dyndns host'};
	push @ret, { name => 'ddns_services', value => \@ddns, attributes => [ type => 'popup'] };
	push @ret, { name => "login", value => "$reply->{login}", attributes => [ type => 'string'] };
	push @ret, { name => "password", value => "$reply->{password}", attributes => [ type => 'string'] };
	push @ret, { name => "hostname", value => "$reply->{hostname}", attributes => [ type => 'string', label => 'host_name', backlabel => "Ex: your-host.easydns.org,  your-host.dyndns.com"] };
	push @ret, { action => 'my_cancel' };
	push @ret, { action => 'save_host' };

	return \@ret;
}

sub save_host
{
	my $this  = shift;
	my $reply = shift;
	my $warn = '';
	my $split_file = split_conf_file();

	$reply->{line} = $reply->{hostname};
	$reply->{hosts}->{$reply->{hostname}}->{ddns_services} = $reply->{ddns_services};

	if( !($reply->{hostname} =~ /^([\-0-9a-zA-Z]+)\.+([\-0-9a-zA-Z]+)\.+([a-zA-Z]+)$/) ){
		$warn .= main::__('Add the host as the example below. (Example : your-host.easydns.org,  your-host.dyndns.com)<br> If you have used special characters please remove them. (Example: ä, ß, á, é, ó, ű)<br>');
	}

	if( !$reply->{login} ){
		$warn .= main::__('Add the registered user name!<br>');
	}
	if( !$reply->{password} ){
		$warn .= main::__("Add the user's password!<br>");
	}
	
	if($warn ne ''){
		$reply->{warning} = "$warn";
		return $this->new_host($reply);
	}

	$split_file->{ddclient_conf}->{$reply->{ddns_services}}->{login} = $reply->{login};
	$split_file->{ddclient_conf}->{$reply->{ddns_services}}->{password} = $reply->{password};
	$split_file->{ddclient_conf}->{$reply->{ddns_services}}->{protocol} = $ddns_settings{$reply->{ddns_services}}->{protocol};
	$split_file->{ddclient_conf}->{$reply->{ddns_services}}->{server} = $ddns_settings{$reply->{ddns_services}}->{server};
	$split_file->{ddclient_conf}->{$reply->{ddns_services}}->{host} = $reply->{hostname};

	$this->save_content_to_file($split_file);

	my $msg = $this->check_host("$reply->{hostname}");
	if($msg){
		$reply->{hosts_status} = $msg;
		return $this->edit_host($reply);
	}else{
		system('rm /etc/ddclient.conf.old');
		return $this->default();
	}
}

sub edit_host
{
	my $this  = shift;
	my $reply = shift;
	my @ret;

	if(exists($reply->{hosts}->{$reply->{line}}->{edit_h})){
		system("cp /etc/ddclient.conf /etc/ddclient.conf.old");
	}

	if(exists($reply->{hosts_status})){
		push @ret, { NOTICE => "$reply->{hosts_status}" };
	}

	my $ddns_service = $reply->{hosts}->{$reply->{line}}->{ddns_services};
	my $split_file = split_conf_file();

	push @ret, { subtitle => 'Edit'};
	push @ret, { label => main::__('Edit')." $reply->{line} Host"};
	push @ret, { name => 'ddns_service', value => "$ddns_services{$ddns_service}", attributes => [ type => 'label'] };
	push @ret, { name => "login", value => "$split_file->{ddclient_conf}->{$ddns_service}->{login}", attributes => [ type => 'string'] };
	push @ret, { name => "password", value => "$split_file->{ddclient_conf}->{$ddns_service}->{password}", attributes => [ type => 'string'] };
	push @ret, { name => "hostname", value => "$split_file->{ddclient_conf}->{$ddns_service}->{host}", attributes => [ type => 'string', backlabel => "Ex: your-host.easydns.org,  your-host.dyndns.com" ] };
	push @ret, { name => "ddns_services", value => "$ddns_service", attributes => [ type => 'hidden'] };
	push @ret, { action => 'my_cancel' };
	push @ret, { action => 'save_host'};

	return \@ret,
}

sub delete_host
{
	my $this  = shift;
	my $reply = shift;
	my $split_file = split_conf_file();

	my $ddns_service = $reply->{hosts}->{$reply->{line}}->{ddns_services};
	delete($split_file->{ddclient_conf}->{$ddns_service});

	$this->save_content_to_file($split_file);
	system("/etc/init.d/ddclient restart");
	return $this->default($reply);
}

#///////////////////////////////////////////////////////////////////////////////////////
#  local subrutin
sub save_content_to_file
{
        my $this  = shift;
        my $split_file = shift;

        my $content = '';
        $content .= $split_file->{ddclinet_conf_head}."\n";
        foreach my $service_name (keys %{$split_file->{ddclient_conf}} ){
                $content .= "\n###\n##$service_name\n";
		$content .= "login=".$split_file->{ddclient_conf}->{$service_name}->{login}.",\t\\\n";
		$content .= "password=".$split_file->{ddclient_conf}->{$service_name}->{password}.",\t\\\n";
		$content .= "protocol=".$split_file->{ddclient_conf}->{$service_name}->{protocol}.",\t\\\n";
		$content .= "server=".$split_file->{ddclient_conf}->{$service_name}->{server}.",\t\\\n";
		$content .= $split_file->{ddclient_conf}->{$service_name}->{host}."\n";
	}

	write_file('/etc/ddclient.conf',$content);
}

sub split_conf_file
{
	my $file = shift || 0;
	my %ddc = ('ddclient_conf');
	my @ret;
	if( !(-e '/etc/ddclient.conf.tmp')){
                system('cp /etc/ddclient.conf /etc/ddclient.conf.tmp');
		my $first_par = "#This file can only be modified from the \"OSSadmin\" platform (on the DynDns page).\n";
		$first_par .= "#Please don't modify it manually.\n";
		$first_par .= "daemon=300\n";
		$first_par .= "syslog=yes\n";
		$first_par .= "mail-failure=root\n";
		$first_par .= "pid=/var/run/ddclient.pid\n";
		$first_par .= "ssl=no\n";
		$first_par .= "use=web, web=checkip.dyndns.org/, web-skip='IP Address'";
		write_file('/etc/ddclient.conf',$first_par);
        }

	my $conf_file;
	if($file eq 1){
		$conf_file = `cat /etc/ddclient.conf.old`;
	}else{
		$conf_file = `cat /etc/ddclient.conf`;
	}
	my @ddns = split("\n\n###\n",$conf_file);
	my $first_par = shift(@ddns);
	$ddc{ddclinet_conf_head} = trim($first_par);
	my $size_ddns = @ddns;

	if( $size_ddns eq 0){
		push @ret, { NOTICE => 'There are no existing settings.'};
	}elsif( $size_ddns ge 0){
		foreach my $dyndns (@ddns){
			if($dyndns =~ /^##(.*)\n(.*)/){
				my $ddc_service = $1;
				my @hosts;
				my @lines = split('\n',$dyndns);
				my $size_lines = @lines;
				for(my $i= 1; $i < $size_lines; $i++){
					$lines[$i] =~ s/#//;
					if($lines[$i] =~ /(.*)=(.*)/){
						my ($param, $value) = split("=",$lines[$i]);
						$value =~ s/,\t\\//;
						$ddc{ddclient_conf}->{$ddc_service}->{$param} = $value;
					}else{
						$ddc{ddclient_conf}->{$ddc_service}->{host} = $lines[$i];
					}
				}
			}
		}
	}
#print Dumper(%ddc)."   ddc\n";
	return \%ddc
}

sub check_host
{
	my $this = shift;
	my $hostname = shift;
	my $msg = '';

	system("/etc/init.d/ddclient stop");
	system("rm /var/cache/ddclient/ddclient.cache");
	system("/etc/init.d/ddclient start");
	sleep 3;
	my $ddclient_cache = `cat /var/cache/ddclient/ddclient.cache`;	
	if($ddclient_cache eq ''){
		$msg .= main::__('Please save again, because the previous save was unsuccessful');
	}
	my @ddclient_c = split("\n",$ddclient_cache);
	shift(@ddclient_c);
	shift(@ddclient_c);
	foreach my $line (@ddclient_c){
		if( $line =~ /(.*),host=([^,]*)(.*),status=([^,]*)(.*)/){
			if( ($2 eq $hostname) and ($4 ne 'good')){
				$msg .= sprintf( main::__('The status of "%s" is either "%s"'), $2, $4 );
			}
		}
	}
	return $msg;
}

sub my_cancel
{
	my $this = shift;
        my $reply = shift;
	my $ddns_service = $reply->{ddns_services};

	if( -e '/etc/ddclient.conf.old'){
		my $split_file = split_conf_file(1);
		system("rm /etc/ddclient.conf.old");
		$this->save_content_to_file($split_file);
	}else{
		my $split_file = split_conf_file();
		delete($split_file->{ddclient_conf}->{$ddns_service});
		$this->save_content_to_file($split_file);
	}

        return $this->default();
}

sub trim($)
{
        my $string = shift;
        $string =~ s/^\s+//;
        $string =~ s/\s+$//;
        return $string;
}

1;
