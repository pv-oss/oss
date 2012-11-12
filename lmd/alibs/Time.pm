# Module for set the system date time & time zone
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package Time;

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
		"Clean",
		"Set"
	];

}

sub getCapabilities
{
	return [
		 { title        => 'Setting Date Time and Time Zone' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { category     => 'System' },
		 { order        => 40 },
		 { variable     => [ "date",	     [ type => "date",  label=>"Actual Date" ] ] },
		 { variable     => [ "time",	     [ type => "time",  label=>"Actual Time" ] ] },
		 { variable     => [ "timeZone",     [ type => "popup",  label=>"Time Zone" ] ] }
	];
}

sub default
{
	my      $TimeZones = getTimeZones();
	my( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst )   = localtime(time);
        my $Date = sprintf('%4d-%02d-%02d',$year+1900,$mon+1,$mday);
        my $Time = sprintf('%02d:%02d',$hour, $min);
	my $t    = `gawk '/^server/ { print \$2 }' /etc/ntp.conf`;
	my ($TimeServer1,$TimeServer2,$TimeServer3) = split /\n/, $t;
	
	return [
		{ date 	      => $Date },
		{ time        => $Time },
		{ timeZone    => $TimeZones },
		{ timeserver1 => $TimeServer1 },
		{ timeserver2 => $TimeServer2 },
		{ timeserver3 => $TimeServer3 },
		{ action      => "Set" }
	];
}

sub Set
{
	my $this   = shift;
	my $Vars   = shift;

        my ($year,$mon,$day)  = split /-/ , $Vars->{'date'};
        my ($hour,$min)       = split /:/ , $Vars->{'time'};

	system("date ".$mon.$day.$hour.$min.$year);
	system("sed -i /^server/d /etc/ntp.conf");
	system("echo 'server ".$Vars->{'timeserver1'}."' >> /etc/ntp.conf") if( $Vars->{'timeserver1'}  );
	system("echo 'server ".$Vars->{'timeserver2'}."' >> /etc/ntp.conf") if( $Vars->{'timeserver2'}  );
	system("echo 'server ".$Vars->{'timeserver3'}."' >> /etc/ntp.conf") if( $Vars->{'timeserver3'}  );
	default();
}

1;
