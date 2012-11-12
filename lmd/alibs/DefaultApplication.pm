# LMD changePassword modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package DefaultApplication;

use strict;
use oss_base;
use oss_LDAPAttributes;
use oss_utils;
use Storable qw(thaw freeze);
use MIME::Base64;
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
		"set"
	];

}

sub getCapabilities
{
	return [
		{ title        => 'Default Application' },
		{ type         => 'command' },
		{ allowedRole  => 'root' },
		{ allowedRole  => 'sysadmins' },
		{ allowedRole  => 'teachers' },
		{ allowedRole  => 'teachers,sysadmins' },
		{ allowedRole  => 'students' },
		{ category     => 'Settings' },
                { order        => 30 },
                { variable     => [ "modules",  [ type => "list", size => 10 ] ] }
	];
}

sub default
{
	my $this   = shift;
	my @modules= ();
	my $role   = main::GetSessionValue('role');
	my $dn     = main::GetSessionValue('dn');
	my $MENU   = thaw(decode_base64(main::GetSessionDatas('MENU','BASE')));
	my $vap    = $this->get_vendor_object($dn,'oss','defaultApplication');

	foreach my $cat ( keys %{$MENU->{$role}} )
	{
		foreach my $mod ( keys %{$MENU->{$role}->{$cat}} )
		{
			push @modules, [ $cat.','.$mod , main::__($cat,'getMenu').' => '.main::__($mod,'getMenu') ];
		}
	}
	if( defined $vap->[0] )
	{
		my @app = split /,/,$vap->[0];
		push @modules, "---DEFAULTS---",$app[0].','.$app[1];
	}
	
	return [
		{ modules  => \@modules },
		{ action    => 'cancel' },
		{ action    => 'set' }
	]
}


sub set
{
	my $this   = shift;
	my $reply  = shift;
	my $dn     = main::GetSessionValue('dn');

	$this->create_vendor_object($dn,'oss','defaultApplication',$reply->{modules}.',default');
	$this->default();
}

1;
