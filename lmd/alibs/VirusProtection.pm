# OSS VirusProtection Module
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package VirusProtection;

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
		"apply",
		"log_files",
		"details",
		"download",
	];
}

sub getCapabilities
{
	return [
		{ title        => 'Configure Virus Protection' },
		{ type         => 'command' },
		{ allowedRole  => 'root' },
		{ allowedRole  => 'sysadmins' },
		{ category     => 'Security' },
		{ order        => 40 },
		{ variable     => [ crontab      => [ type => 'boolean', label=>"Scan file system everyday" ] ] },
		{ variable     => [ onthefly     => [ type => 'boolean', label=>"Scan file system on the fly" ] ] },
		{ variable     => [ time         => [ type => 'time',    label=>"Time for daily scan" ] ] },
	];
}

sub default
{
	my $this  = shift;
	my $reply = shift;
	my $c = 0;
	my $t= '02:00';

	if( -e "/etc/cron.d/oss.virus-protection" ){
		$c = 1;
		$t = cmd_pipe("gawk '{ printf(\"%02i:%02i\",\$2,\$1)}' /etc/cron.d/oss.virus-protection");
	}

	return
	[
	   { crontab => $c },
	   { time  =>  $t },
	   { action => "log_files"},
	   { action => "apply" }
	];
}

sub apply
{
	my $this  = shift;
	my $reply = shift;

	if ( $reply->{crontab} ){
		cmd_pipe("mkdir -p /tmp/VIRUS; mkdir -p /var/log/virus_scan_logs");
		my ($hour, $minute) = split(":", $reply->{time});
		my $cmd = "$minute $hour * * * root /usr/share/oss/tools/scan-home.sh\n\n";
		write_file('/etc/cron.d/oss.virus-protection',$cmd);
	}
	else
	{
		cmd_pipe("test -e /etc/cron.d/oss.virus-protection && rm /etc/cron.d/oss.virus-protection");
	}
	$this->default;
}

sub log_files
{
	my $this  = shift;
	my $reply = shift;
	my @lines = ('logs');
	my $language =  main::GetSessionValue('lang');
	push @lines, { head => [ "id", "date_time", "status" ] };
	my $i = 1;

	foreach my $f ( reverse ( glob "/var/log/virus_scan_logs/*.log" ) )
	{
		$f =~ /\/var\/log\/virus_scan_logs\/(.*).log/;
		my ($date, $time ) = split( "_",$1 );
		$date = date_format_convert("$language","$date");
		my @time_sp = split(":", $time);
		$time = $time_sp[0].":".$time_sp[1];
		my $status = main::__('OK');
		my $tmp = cmd_pipe("grep FOUND $f");
		my $color = 'blue';
		if( $tmp ){
			$status = main::__("Virus found");
			$color = 'red';
			push @lines, { line => [ $f,
					{ name => 'id', value => "$i", attributes => [ type => 'label', style => "color:".$color ] },
					{ name => 'date_time', value => "$date $time", attributes => [ type => 'label', style => "color:".$color ] },
                                        { name => 'status', value => "$status", attributes => [ type => 'label', style => "color:".$color ] },
                                        { name => 'details', value => main::__("details"), attributes => [ type => 'action'] },
					{ name => 'download', value => main::__("download"), attributes => [ type => 'action'] },
                        ]};
		}
		else
		{
			push @lines, { line => [ $f,
					{ name => 'id', value => "$i", attributes => [ type => 'label', style => "color:".$color ] },
					{ name => 'date_time', value => "$date $time", attributes => [ type => 'label', style => "color:".$color ] },
					{ name => 'status', value => "$status", attributes => [ type => 'label', style => "color:".$color ] },
			]};
		}
		$i++;
	}

	if ( scalar(@lines) > 2 ){
		return
		[
		   { subtitle => main::__("List of Logs") },
		   { table => \@lines },
		   { action => "cancel" },
		];
	}else{
		return
		[
		   { subtitle => main::__("List of Logs") },
		   { NOTICE => main::__("No log file") },
		   { action => "cancel" },
		]
	}
}

sub details
{
	my $this  = shift;
	my $reply = shift;
	my @lines = ('logs');
	my $i = 1;
	$reply->{line} =~ s/:/\\:/g;
	my $tmp = cmd_pipe("grep FOUND $reply->{line}");
	my @tmp_splt = split("\n", $tmp);
	push @lines, { head => [ "id", "file_path", "status" ] };

	foreach my $line (@tmp_splt)
	{
		my ($file_path, $status) = split(": ", $line);
		if($status =~ /(.*)FOUND(.*)/){
			push @lines, { line => [ $i,
					{ name => 'id', value => "$i", attributes => [ type => 'label', style => "color:red" ] },
					{ name => 'file_path', value => "$file_path", attributes => [ type => 'label', style => "color:red" ] },
					{ name => 'status', value => "$status", attributes => [ type => 'label', style => "color:red" ] },
				]};
			$i++;
		}
	}

	return
	[
	   { subtitle => main::__("Details of logs") },
	   { table => \@lines },
	   { action => "cancel" },
	];

}

sub download
{
	my $this  = shift;
	my $reply = shift;
	my @lines = ('logs');
	$reply->{line} =~ /\/var\/log\/virus_scan_logs\/(.*).log/;
	my $date_time = $1;
	my $file_name = "virus_scan_".$date_time.".log";
	my $log_content = cmd_pipe("cat $reply->{line}");
	return
	[
	   { name => 'download', value=>encode_base64($log_content), attributes => [ type => 'download', filename=> "$file_name", mimetype=>'text/plain']}
	]
}

1;
