# LMD Template modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package Template;

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
		"clean",
		"set",
		"read"
	];

}

sub getCapabilities
{
	return [
		 { title        => 'Test Modul' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { category     => 'Security' },
		 { order        => 1 },
		 { variable     => [ "testFile", [ type => "string", label=>"file" ] ] },
		 { variable     => [ "testText", [ type => "text"  , label=>"Content" ] ] }
	];
}

sub default
{
	my $testFile	= '';
	my $testText	= '';
	if ( -e "/tmp/test.lastfile" )
	{
		$testFile = `cat /tmp/test.lastfile`;
		chomp $testFile;
		$testText = `cat $testFile`;
		chomp $testText;
	}
	return [
		{ testFile => $testFile },
		{ testText => $testText },
		{ action   => "clean" },
		{ action   => "read" },
		{ action   => "set" }
	];
}

sub clean
{
	my $this   = shift;
	my $reply  = shift;

	my $testFile   = $reply->{testFile};

	if ( -e "$testFile" )
	{
        	system("echo > '$testFile'");
	}
	return [
		{ testFile => $testFile },
		{ testText => '' },
		{ action   => "clean" },
		{ action   => "read" },
		{ action   => "set" }
	];
}

sub set
{
	my $this   = shift;
	my $reply  = shift;

	my $testFile   = $reply->{testFile};
	my $testText   = $reply->{testText};
	system( "echo '$testFile' > /tmp/test.lastfile" );
        system( "echo '$testText' > $testFile");
	return [
		{ testFile => $testFile },
		{ testText => $testText },
		{ action   => "clean" },
		{ action   => "read" },
		{ action   => "set" }
	];
}

sub read
{
	my $this   = shift;
	my $reply  = shift;

	my $testFile   = $reply->{testFile};
        my $testText   = `cat $testFile`;
	chomp $testText;
	system( "echo '$testFile' > /tmp/test.lastfile" );

	return [
		{ testFile => $testFile },
		{ testText => $testText },
		{ action   => "clean" },
		{ action   => "read" },
		{ action   => "set" }
	];
}

1;
