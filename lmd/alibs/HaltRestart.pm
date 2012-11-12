# LMD HaltRestart modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package HaltRestart;

use strict;
use Data::Dumper;
use oss_base;
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
		"Clean",
		"Set"
	];

}

sub getCapabilities
{
	return [
		 { title        => 'Shut Down or Reboot the System' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { category     => 'System' },
		 { order        => 50 },
		 { variable     => [ "shutDownDate", [ type => "date",  label=>"Date" ] ] },
		 { variable     => [ "shutDownTime", [ type => "time",  label=>"Time" ] ] },
		 { variable     => [ "reboot",       [ type => "boolean", label=>"Reboot" ] ] },
		 { variable     => [ "immediately",  [ type => "boolean", label=>"Immediately" ] ] },
	];
}

sub default
{
	my	$Date   ='';
	my	$Time   ='';
	my	$Reboot =0;

	if( -e "/etc/cron.d/HaltRestart" )
	{
		system("mv /etc/cron.d/HaltRestart /etc/cron.d/oss.HaltRestart");
	}
	if( -e "/etc/cron.d/oss.HaltRestart" )
	{
		my $content = `cat /etc/cron.d/oss.HaltRestart`;
		my( $Hmin, $Hhour, $Hday, $Hmon, $Hwday, $Huser, $Hcommand) = split /\s+/, $content;
		my( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst )   = localtime(time);
		my $reboottime = $Hmon*43200+$Hday*1440+$Hhour*60+$Hmin ;
		my $now        = ($mon+1)*43200+$mday*1440+$hour*60+$min ;
		if( $reboottime > $now )
		{
		   $year += 1900;
		}
		else
		{
		   $year += 1901;
		}
		$Date = sprintf('%4d-%02d-%02d',$year,$Hmon,$Hday); 
		$Time = sprintf('%02d:%02d',$Hhour, $Hmin);
		if( $Hcommand =~ /reboot/ )
		{
			$Reboot = 1;
		}
	}
	
	return [
		{ shutDownDate => $Date },
		{ shutDownTime => $Time },
		{ reboot       => $Reboot },
		{ immediately  => 0 },
		{ action       => "Clean" },
		{ action       => "Set" }
	];
}

sub Clean
{

	if( -e "/etc/cron.d/oss.HaltRestart" )
	{
		unlink "/etc/cron.d/oss.HaltRestart";
	}
	return default();

}

sub Set
{
	my $this   = shift;
	my $Vars   = shift;

	my ($year,$mon,$day)  = split /-/ , $Vars->{'shutDownDate'};
	my ($hour,$min)       = split /:/ , $Vars->{'shutDownTime'};
	my $command	     = "/sbin/halt";

	if( $Vars->{'reboot'} )
	{
		$command = "/sbin/reboot";
	}

	if( $Vars->{'immediately'} )
	{
		if( -e "/etc/cron.d/oss.HaltRestart" )
		{
			unlink "/etc/cron.d/oss.HaltRestart";
		}
		system("$command");
	}
	else
	{
		system("echo '$min $hour $day $mon * root $command' > /etc/cron.d/oss.HaltRestart");
		system("echo  >> /etc/cron.d/oss.HaltRestart" );
	}

	default();
}

1;
