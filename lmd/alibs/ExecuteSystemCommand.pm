# LMD ExecuteSystemCommand modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ExecuteSystemCommand;

use strict;
use oss_base;
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
		"execute"
	];

}

sub getCapabilities
{
	return [
		 { title        => 'Execute System Command' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { category     => 'System' },
		 { order        => 130 },
		 { variable     => [ "command",   [ type => "string", label=>"Command to Execute" ] ] },
		 { variable     => [ "output",    [ type => "text"  , label=>"Output of the Command" ] ] }
	];
}

sub default
{
	my $this   = shift;
	my $reply  = shift;

	return [
		{ command   => "" },
		{ action    => "cancel" },
		{ action    => "execute" }
	];
}

sub execute
{
	my $this   = shift;
	my $reply  = shift;

	my $command   = $reply->{command};
	my $output    = `$command`;
	return [
		{ command   => $command },
		{ output    => $output },
		{ action    => "cancel" },
		{ action    => "execute" }
	];
}

1;
