# LMD ConfigOSS module
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ConfigOSS;

use strict;
use oss_user;
use oss_utils;
use Data::Dumper;
use vars qw(@ISA);
@ISA = qw(oss_base);
use Config::IniFiles;

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
	];
}

sub getCapabilities
{
	return [
		{ title        => 'Basic Configuration of OSS' },
		{ type         => 'command' },
		{ allowedRole  => 'root' },
		{ allowedRole  => 'sysadmins' },
		{ category     => 'Settings' },
		{ order        => 30 },
	];
}

sub default
{
	my $this  = shift;
	my $reply = shift;
	my @ret;
	push @ret, { NOTICE => main::__('not_be_must_changed_notice') };

	if( exists($reply->{warning}) ){
		push @ret, { NOTICE => "$reply->{warning}" };
	}
	my %hash;
        my $tmp = cmd_pipe('cat /etc/sysconfig/lmd');
        my @tmp = split("\n\n", $tmp);
        foreach my $sec ( @tmp ){
                my @tmp2 = split("\n", $sec);
                @tmp2 = reverse sort @tmp2;
                my $head = shift(@tmp2);
                next if( $head !~ /^(LMD_.*)=(.*)/);
                my $head_name = $1;
                $hash{$head_name}->{value} = cmd_pipe(". /etc/sysconfig/lmd ; echo \$".$head_name);
                foreach my $line ( sort @tmp2 ){
                        if( $line =~ /^## Default:(.*)/){
                                $hash{$head_name}->{default_value} = main::__('Default value:').$1;
                                $hash{$head_name}->{default_value} =~ s/\"/ /g;
                        }
                        if( $line =~ /^# (.*)/){
                                $hash{$head_name}->{help} .= " ".$1;
                                $hash{$head_name}->{help} =~ s/\"/ /g;
                        }
                }
        }

	#LMD_SESSION_TIMEOUT
	my @sessiontimeout;
	for my $num (5 .. 200){
		push @sessiontimeout, $num;
	}
	push @sessiontimeout , '---DEFAULTS---', $hash{LMD_SESSION_TIMEOUT}->{value};

	#LMD_DISABLED_MODULES
	my @disabled_modules;
	my $tmp = `ls /usr/share/lmd/alibs/`;
	my @tmp = split("\n", $tmp);
	foreach my $item ( @tmp ){
		if( $item =~ /^(.*).(pm|sh)$/){
			push @disabled_modules, $1;
		}
	}
	my @def_disabled_modules = split(",", $hash{LMD_DISABLED_MODULES}->{value});
	push @disabled_modules, '---DEFAULTS---', @def_disabled_modules;

	push @ret, { name => 'LMD_ADDRESS', value => $hash{LMD_ADDRESS}->{value}, attributes => [ type => "string", style => "width:100px", help => "$hash{LMD_ADDRESS}->{help}.  $hash{LMD_ADDRESS}->{default_value}" ] };
	push @ret, { name => 'LMD_PORT', value => $hash{LMD_PORT}->{value}, attributes => [ type => "string", style => "width:100px", help => "$hash{LMD_PORT}->{help}.  $hash{LMD_PORT}->{default_value}" ] };
	push @ret, { name => 'LMD_SESSION_TIMEOUT', value => \@sessiontimeout, attributes => [ type => "popup", backlabel => main::__('minutes'), help => "$hash{LMD_SESSION_TIMEOUT}->{help}.  $hash{LMD_SESSION_TIMEOUT}->{default_value}" ] };
	push @ret, { name => 'LMD_DISABLED_MODULES', value => \@disabled_modules, attributes => [ type => "list", size => '10', multiple => "true", help => "$hash{LMD_DISABLED_MODULES}->{help}.  $hash{LMD_DISABLED_MODULES}->{default_value}" ] };
	push @ret, { name => 'LMD_CATEGORY_ORDER', value => $hash{LMD_CATEGORY_ORDER}->{value}, attributes => [ type => "string", style => "width:400px", help => "$hash{LMD_CATEGORY_ORDER}->{help}.  $hash{LMD_CATEGORY_ORDER}->{default_value}" ] };
	push @ret, { name => 'LMD_USE_MENU_ICONS', value => [ 'yes', 'no', '---DEFAULTS---', $hash{LMD_USE_MENU_ICONS}->{value} ], attributes => [type => "popup", help => "$hash{LMD_USE_MENU_ICONS}->{help}.  $hash{LMD_USE_MENU_ICONS}->{default_value}" ] };
	push @ret, { name => 'LMD_ARCHIVE_REQUESTS', value => [ 'yes', 'no', '---DEFAULTS---', $hash{LMD_ARCHIVE_REQUESTS}->{value} ], attributes => [ type => "popup", help => "$hash{LMD_ARCHIVE_REQUESTS}->{help}.  $hash{LMD_ARCHIVE_REQUESTS}->{default_value}" ] };
	push @ret, { name => 'LMD_APPLICATIONS_TO_ARCHIVE', value => $hash{LMD_APPLICATIONS_TO_ARCHIVE}->{value}, attributes => [ type => "string", style => "width:400px", help => "$hash{LMD_APPLICATIONS_TO_ARCHIVE}->{help}.  $hash{LMD_APPLICATIONS_TO_ARCHIVE}->{default_value}" ] };
	push @ret, { name => 'LMD_APPLICATIONS_NOT_TO_ARCHIVE', value => $hash{LMD_APPLICATIONS_NOT_TO_ARCHIVE}->{value}, attributes => [ type => "string", style => "width:400px", help => "$hash{LMD_APPLICATIONS_NOT_TO_ARCHIVE}->{help}.  $hash{LMD_APPLICATIONS_NOT_TO_ARCHIVE}->{default_value}" ] };
	push @ret, { action => 'apply' };
	return \@ret;
}

sub apply
{
	my $this  = shift;
	my $reply = shift;

	$reply->{LMD_DISABLED_MODULES} =~ s/\n/,/g;

	foreach my $item (keys %{$reply}){
		next if($item eq 'NOTICE'); 
		next if($item eq 'APPLICATION');
		next if($item eq 'SESSIONID');
		next if($item eq 'ACTION');
		next if($item eq 'CATEGORY');
		next if($item eq 'warning');

		my $msg = '';
		if( ($item eq 'LMD_ADDRESS') and ($reply->{$item} !~ /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/)){
			$msg .= main::__('Please enter a valid IP address (LMD_ADDRESS) !')."<BR>";
		}
		if( ($item eq 'LMD_PORT') and ($reply->{$item} !~ /^[0-9]{1,6}$/)){
			$msg .= main::__('Please enter a valid port number (LMD_PORT) !')."<BR>";
		}
		if( $msg ){
			$reply->{warning} = $msg;
			return $this->default($reply);
		}
		cmd_pipe("sed -i 's/^$item=.*/$item=\"$reply->{$item}\"/' /etc/sysconfig/lmd");
	}

	system('rclmd restart');
	$this->default();
}

1;
