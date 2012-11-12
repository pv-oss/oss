# LMD AdminTools modul
# Copyright (c) 2012 EXTIS GmbH, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package AdminTools;

use strict;
use oss_base;
use oss_utils;
use XML::Simple;
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
		"edit_script",
		"run_script",
		"check_log_file",
	];
}

sub getCapabilities
{
	return [
		{ title        => 'AdminTools' },
		{ type         => 'command' },
		{ allowedRole  => 'root' },
		{ allowedRole  => 'sysadmins' },
		{ category     => 'System' },
		{ order        => 38 },
		{ variable     => [ "edit_script",        [ type => 'action' ] ] },
		{ variable     => [ "check_log_file",     [ type => 'action' ] ] },
		{ variable     => [ "script_url",         [ type => 'hidden' ] ] },
        ];
}

sub default
{
	my $this   = shift;
	my $reply  = shift;
	my @lines = ('admintools');
	my @ret;

	if( !(-e "/usr/share/oss/tools/scripts_list.xml") ){
		system('/usr/share/oss/tools/make_scripts_list.pl &');
		return [
			{ NOTICE => main::__('Please wait a few seconds (10 - 15) and refresh the "AdminTools" page.') },
		];
	}else{
		my $xml = new XML::Simple;   
		my $scripts = $xml->XMLin("/usr/share/oss/tools/scripts_list.xml"); 
		push @lines, { head => ['name', 'description' ]};
		foreach my $info ( sort { lc($a) cmp lc($b) } keys %{$scripts} ){
			$scripts->{$info}->{DESCRIPTION} =~ s/</&lt;/g;
			$scripts->{$info}->{DESCRIPTION} =~ s/>/&gt;/g;
			$scripts->{$info}->{DESCRIPTION} =~ s/\n/<BR>/g;
			$scripts->{$info}->{DESCRIPTION} =~ s/\t/&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;/g;
			push @lines, { line => [ "$info",
						{ name => 'script_name', value => "$info", attributes => [ type => 'label' ] },
						{ name => 'script_desc', value => "$scripts->{$info}->{DESCRIPTION}", attributes => [ type => 'label' ] },
						{ edit_script    => main::__('edit_script') },
						{ check_log_file => main::__('check_log_file') },
						{ script_url => "/usr/share/oss/tools/$info" },
				]};
		}

		push @ret, { table  => \@lines };
		return \@ret;
	}
}

sub edit_script
{
	my $this  = shift;
	my $reply = shift;
	my $script_name   = $reply->{line};
	my $xml = new XML::Simple;
	my $scripts = $xml->XMLin("/usr/share/oss/tools/scripts_list.xml");
	my $script_mandatory_params = $scripts->{$script_name}->{PARAMETERS}->{MANDATORY};
	my $script_optional_params = $scripts->{$script_name}->{PARAMETERS}->{OPTIONAL};
	my $script_desc = $scripts->{$script_name}->{DESCRIPTION};
	$script_desc =~ s/</&lt;/g;
	$script_desc =~ s/>/&gt;/g;
	$script_desc =~ s/\n/<BR>/g;
	$script_desc =~ s/\t/&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;/g;
	$script_desc =~ s/ /&nbsp;/g;


	my $mand_params = $this->split_parameters( $script_mandatory_params );
	my @mandatory_params = ('mandatory_params');
	if( !(\$mand_params =~ /scalar/i) ){
		push @mandatory_params, { head => [ ] };
		foreach my $type ( sort keys %{$mand_params}){
			foreach my $param (sort keys %{$mand_params->{$type}} ){
				push @mandatory_params , { line => [ $param ,
							{ name => 'name', value => "$param", attributes => [type=>'label',help=>"$mand_params->{$type}->{$param}"] },
							{ name => 'value', value => "", attributes => [ type => "$type" ] },
					]};
			}
		}
	}

	my $opti_params = $this->split_parameters( $script_optional_params );
	my @optional_params = ('optional_params');
	push @optional_params, { head => [ ] };
	foreach my $type ( sort keys %{$opti_params}){
		foreach my $param (sort keys %{$opti_params->{$type}} ){
			push @optional_params , { line => [ $param ,
						{ name => 'name', value => "$param", attributes => [type=>'label',help=>"$opti_params->{$type}->{$param}"] },
						{ name => 'value', value => "", attributes => [ type => "$type" ] },
				]};
		}
	}

	my @ret;
	push @ret, { subtitle   => main::__('edit_script').": \"$script_name\"" };
	push @ret, { NOTICE     => "$script_desc" };
	if(\$mand_params =~ /scalar/i){
		push @ret, { NOTICE     => "$mand_params" };
	}else{
		push @ret, { label      => main::__('Manadory script parameters') };
		push @ret, { table      => \@mandatory_params };
	}
	push @ret, { label      => main::__('Optional script parameters') };
	push @ret, { table      => \@optional_params };
	push @ret, { script_url => "$reply->{admintools}->{$script_name}->{script_url}" };
	push @ret, { action     => 'cancel' };
	push @ret, { action     => 'run_script' };
	return \@ret;
}

sub run_script
{
	my $this  = shift;
	my $reply = shift;
	my @ret;

	my $cmd = "$reply->{script_url} ";

	if( $reply->{optional_params}->{help}->{value} ){
		$cmd .= "--help ";
	}
	if( $reply->{optional_params}->{description}->{value} ){
		$cmd .= "--description ";
	}

	foreach my $param (keys %{$reply->{mandatory_params}}){
		if( $reply->{mandatory_params}->{$param}->{value} ){
			$cmd .= "--$param=$reply->{mandatory_params}->{$param}->{value} ";
		}
	}

	$reply->{script_url} =~ /^\/usr\/share\/oss\/tools\/(.*)/;
	my $script_name = $1;
	push @ret, { subtitle => main::__('run_script').": \"$script_name\"" };
	push @ret, { NOTICE => sprintf(main::__('Job started. ( run command : "%s")'), $cmd) };
	$script_name =~ s/.pl|.sh//g;
	$cmd .= ">> /var/log/ossscripts/$script_name-timestamp.log";

	if( !(-d "/var/log/ossscripts/") ){
		system('mkdir -p /var/log/ossscripts/');
	}
#	print $cmd."---->cmd\n";
	system("date +%Y-%m-%d.%H-%M-%S | awk '{print \"\\n-log-timestamp : \"\$i\" #:\"}' >> /var/log/ossscripts/$script_name-timestamp.log");
	system("$cmd &");

	push @ret, { name => 'script_url', value => "$reply->{script_url}", attributes => [ type => 'hidden'] };
	push @ret, { action => 'check_log_file' };
	return \@ret;
}

sub check_log_file
{
	my $this  = shift;
	my $reply = shift;
	my $script_url = $reply->{script_url} || $reply->{admintools}->{$reply->{line}}->{script_url};
	$script_url =~ /^\/usr\/share\/oss\/tools\/(.*)/;
	my $script_name = $1;
	my $log_file_path = "/var/log/ossscripts/$script_name-timestamp.log";
	$log_file_path =~ s/.pl|.sh//g;

	if( !(-e "$log_file_path") ){
		return [
			{ subtitle => "\"$script_name\"" },
			{ NOTICE => sprintf( main::__('Nem volt meg hasznalva a "%s" script az ossadmin feluletrol, igy nem letezik a logfile'), $script_name ) },
			{ action => 'cancel' },
		];
	}

	my $log_file_content = `cat $log_file_path`;
	my @script_logs = split("\n-log-timestamp : ", $log_file_content);

	my %hash;
	foreach my $log( @script_logs ){
		my ( $date, $log_content ) = split(" #:\n", $log);
		$hash{$date} = $log_content;
	}

	my @lines = ('logs');
	foreach my $date ( sort { $b cmp $a } keys %hash ){
		next if( !$date );
		if( !$hash{$date} ){ $hash{$date} = "-"};
		$hash{$date} =~ s/</&lt;/g;
		$hash{$date} =~ s/>/&gt;/g;
		$hash{$date} =~ s/\n/<BR>/g;
		$hash{$date} =~ s/\t/&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;/g;
		push @lines, { line => [ "$date",
						{ name => "date", value => "$date", attributes => [ type => 'label'] },
						{ name => "log_value", value => "$hash{$date}", attributes => [ type => 'label'] },
			]};
	}

	$script_name =~ s/.pl|.sh//g;
	return [
		{ subtitle => main::__('Log').": \"$script_name-timestamp.log\""},
		{ table => \@lines },
		{ action => 'cancel' },
	];
}

#----------------local function--------------

sub split_parameters
{
	my $this = shift;
	my $script_params = shift;

	my @params = split( ";", $script_params);
        my %hash;
#print Dumper(@params); exit;
        foreach my $param ( @params){
                my ( $param_n, $param_d ) = split("==", $param);
		print $param_n."--->\n";
		print $param_d."---<\n";
		if( $param_n and !$param_d){
			return $param_n;
		}
                $param_d =~ s/"//g;
                $param_d =~ /(.*)\(type=(.*)\)(.*)/;
                $hash{$2}->{$param_n} .= $param_d.", ";
        }

	return \%hash;
}

1;
