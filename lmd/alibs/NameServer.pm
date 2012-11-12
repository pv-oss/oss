# LMD NameServer modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package NameServer;

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
		"Set",
	];

}

sub getCapabilities
{
	return [
		 { title        => 'Resolver Configuration' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { category     => 'Network' },
		 { order        => 100 },
		 { variable     => [ "nameServer1",  [ type => "string", label=>"Name Server 1" ] ] },
		 { variable     => [ "nameServer2",  [ type => "string", label=>"Name Server 2" ] ] },
		 { variable     => [ "nameServer3",  [ type => "string", label=>"Name Server 3" ] ] },
		 { variable     => [ "searchList",   [ type => "string", label=>"Search List" ] ] }
	];
}

sub default
{
        my @nameserver = ( '', '', '' );
	my $i          = 0;
        my $search     = '';

	open(FILE,'/etc/resolv.conf');
	while(<FILE>)
        {
		if( /^nameserver (.*)/)
		{
			$nameserver[$i] =  $1; $i++;
		}
		elsif( /^search (.*)/)
		{
			$search = $1;
		}
	}
	close(FILE);

	return [
		{ nameServer1  => $nameserver[0] },
		{ nameServer2  => $nameserver[1] },
		{ nameServer3  => $nameserver[2] },
		{ searchList   => $search },
		{ action       => "cancel" },
		{ action       => "Set" }
	];
}

sub Set
{
	my $this   = shift;
	my $reply  = shift  || return undef;

	open(FILE,'>/etc/resolv.conf');

	if( $reply->{nameServer1} ne '' )
	{
		print FILE 'nameserver '.$reply->{nameServer1}."\n";
	}
	if( $reply->{nameServer2} ne '' )
	{
		print FILE 'nameserver '.$reply->{nameServer2}."\n";
	}
	if( $reply->{nameServer3} ne '' )
	{
		print FILE 'nameserver '.$reply->{nameServer3}."\n";
	}
	if( $reply->{searchList} ne '' )
	{
		print FILE 'search '.$reply->{searchList}."\n";
	}
	close(FILE);

	default();
}

1;
