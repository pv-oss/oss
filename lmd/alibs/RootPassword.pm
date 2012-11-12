# LMD RootPassword modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package RootPassword;

use strict;
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
		"abort",
		"set",
		"OK",
	];

}

sub getCapabilities
{
	return [
		 { title        => 'Setting the Root Password' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { category     => 'Security' },
		 { order        => 1 },
		 { variable     => [ "rootPassword1", [ type => "password", label=>"New Password" ] ] },
		 { variable     => [ "rootPassword2", [ type => "password", label=>"Confirm New Password" ] ] }
	];
}

sub default
{
	return [
		{ rootPassword1 => '' },
		{ rootPassword2 => '' },
		{ action   => "abort" },
		{ action   => "set" }
	];
}


sub set
{
	my $this   = shift;
	my $reply  = shift;

	my $rootPassword1   = $reply->{rootPassword1};
	my $rootPassword2   = $reply->{rootPassword2};
	if( $rootPassword1 ne $rootPassword2 )
	{
		return [
			{ ERROR         => "New passwords do not match.\nTry again." },
			{ action        => "OK" },
		];
	}
	elsif( $rootPassword1 =~ /\s/ )
	{
		return [
			{ ERROR         => "Password must not contain white spaces." },
			{ action        => "OK" },
		];
	}
	elsif( length($rootPassword1) < 5 )
	{
		return [
			{ ERROR         => "Password too short." },
			{ action        => "OK" },
		];
	}
	else
	{
		system("echo $rootPassword1 | /usr/bin/passwd --stdin root");
	}

	default;
}

sub abort
{
	default;
}

sub OK
{
	default;
}

1;
