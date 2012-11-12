# LMD FileEdit modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package FileEdit;

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
		"filetree_dir_open",
		"default",
		"Clean",
		"Save",
		"Read",
		"filetree_dir_open"
	];

}

sub getCapabilities
{
	return [
		 { title        => 'Edit System Files' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { category     => 'System' },
		 { order        => 120 },
		 { variable     => [ "makeBackup", [ type => "boolean",  label=>"Make Backup" ] ] },
		 { variable     => [ "testFile",   [ type => "filetree", label=>"file" ] ] },
		 { variable     => [ "testText",   [ type => "text"  ,   label=>"Content" ] ] }
	];
}

sub default
{
	my $this   = shift;
	my $reply  = shift;
	my $uid    = get_name_of_dn($this->{aDN});
	if( ! defined $reply->{testFile} )
	{
		$reply->{testFile} = '/';
	}
	if( $uid eq 'Administrator' )
	{
		$uid='admin';
	}
	my $testFile = cmd_pipe("/usr/share/oss/tools/print_dir.pl","uid $uid\npath ".$reply->{testFile});
	my $testText	= '';
	return [
		{ testFile   => $testFile },
		{ makeBackup => 1 },
		{ testText   => $testText },
		{ action     => "Clean" },
		{ action     => "Read" },
		{ action     => "Save" }
	];
}

sub filetree_dir_open
{
	my $this   = shift;
	my $reply  = shift;
	$this->default($reply);
}

sub Clean
{
	my $this   = shift;
	my $reply  = shift;

	my $testFile   = $reply->{testFile};

	if ( -e "$testFile" )
	{
        	system("echo > '$testFile'");
		system("echo '$testFile' > /tmp/test.lastfile" );
	}
	return [
		{ testFile   => $testFile },
		{ makeBackup => 1 },
		{ testText   => '' },
		{ action     => "Clean" },
		{ action     => "Read" },
		{ action     => "Save" }
	];
}

sub Save
{
	my $this   = shift;
	my $reply  = shift  || return undef;
	my $date   = `date +\%Y-\%m-\%d-\%H:\%M:\%S`; chomp $date;

	if( ! defined $reply->{testFile} || ! defined $reply->{testText} )
	{
		return undef;
	}
	my $testFile   = $reply->{testFile};
	my $testText   = $reply->{testText};
	system( "echo '$testFile' > /tmp/test.lastfile" );
	if( defined $reply->{makeBackup} )
	{
            system( "cp $testFile $testFile-$date");
	}    
	open(FILE,">$testFile");
	print FILE $testText;
	close(FILE);
	return [
		{ testFile   => $testFile },
		{ makeBackup => 1 },
		{ testText   => $testText },
		{ action     => "Clean" },
		{ action     => "Read" },
		{ action     => "Save" }
	];
}

sub Read
{
	my $this   = shift;
	my $reply  = shift;

	my $testFile   = $reply->{testFile};
        my $testText   = `cat $testFile`;
	chomp $testText;
	system( "echo '$testFile' > /tmp/test.lastfile" );

	return [
		{ testFile => $testFile },
		{ makeBackup => 1 },
		{ testText => $testText },
		{ action   => "Clean" },
		{ action   => "Read" },
		{ action   => "Save" }
	];
}

1;
