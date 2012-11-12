# LMD PostFile modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package PostFile;

use strict;
use oss_pedagogic;
use oss_utils;
use MIME::Base64;
use vars qw(@ISA);
@ISA = qw(oss_pedagogic);

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    my $self    = oss_pedagogic->new($connect);
    return bless $self, $this;
}

sub interface
{
	return [
		"getCapabilities",
		"default",
		"clean",
		"all_groups",
		"show_member",
		"post_it",
		"getIt",
		"filetree_dir_open"
	];

}

sub getCapabilities
{
	return [
		 { title        => 'Post File' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { allowedRole  => 'teachers' },
		 { allowedRole  => 'teachers,sysadmins' },
		 { category     => 'Students' },
		 { order        => 10 },
		 { variable     => [ "path",         [ type => "filetree", label=>"My Documents", can_choose_dir => "true" ] ] },
		 { variable     => [ "file",         [ type => "filefield" ] ] },
		 { variable     => [ "all_groups",   [ type => "hidden" ] ] },
		 { variable     => [ "clear_export", [ type => "boolean"] ] },
		 { variable     => [ "clear_home",   [ type => "boolean"] ] },
                 { variable     => [ "users",        [ type => "list", size=>"20", multiple=>"true" ] ] },
                 { variable     => [ "class",        [ type => "list", size=>"5", multiple=>"true" ] ] },
                 { variable     => [ "group",        [ type => "list", size=>"5", multiple=>"true" ] ] }
	];
}

sub filetree_dir_open
{
	my $this   = shift;
	my $reply  = shift;
	$this->default($reply);
}

sub all_groups
{
	my $this   = shift;
	my $reply  = shift;
	$reply->{all_groups} = 1;
	$this->default($reply);
}

sub default
{
	my $this   = shift;
	my $reply  = shift;
	my $uid    = get_name_of_dn($this->{aDN});
	my $path   = $reply->{path} || $this->get_attribute($this->{aDN},'homeDirectory');
        if( $uid eq 'Administrator' )
        {
                $uid='admin';
        }
	my $dirs = cmd_pipe("/usr/share/oss/tools/print_dir.pl","uid $uid\npath $path");
	my ( $roles, $classes, $groups ) = $this->get_school_groups_to_search($this->{aDN});
	if( $reply->{all_groups} )
	{
		( $roles, $classes, $groups ) = $this->get_school_groups_to_search();
	}
	my @r = ( 
			{ all_groups   	=> $reply->{all_groups} },
			{ path     	=> $dirs },
			{ file     	=> '' }
		);
	my $room = main::GetSessionValue('room');
	if( $room )
	{
		push @r ,
		{ name		=> 'class_room',
		  value         => 0,
		  attributes    => [ type => "boolean" , label => main::__('class_room').' '.$room ]
		};
		push @r ,
		{ name		=> 'class_room_users',
		  value         => 0,
		  attributes    => [ type => "boolean" , label => main::__('class_room_users').' '.$room ]
		};
	}
	push @r, (
			{ class	   	=> $classes },
			{ group	   	=> $groups  },
			{ clear_export	=> 1 }
		);
	if( $room )
	{
		push @r , { clear_home	=> 1 };
	}
	push @r, (
			{ action   	=> "cancel" },
			{ action   	=> "show_member" },
			{ action   	=> "all_groups" },
			{ action   	=> "post_it" }
		);
	return \@r;
}

sub show_member
{
	my $this   = shift;
	my $reply  = shift;
	my $uid    = get_name_of_dn($this->{aDN});
	my $path   = $reply->{path} || '';
	my $dirs = cmd_pipe("/usr/share/oss/tools/print_dir.pl","uid $uid\npath $path");
	my @users  = ();
	my $exists = {};
	my @groups = split /\n/, $reply->{class};
	push @groups, split /\n/, $reply->{group};
	foreach my $g (@groups)
	{
		my $students = $this->get_students_of_group($g,1);
		foreach my $user ( keys %{$students} ) {
			next if $exists->{$user};
			push @users , [ $user , $students->{$user}->{cn}->[0].' ('.$students->{$user}->{uid}->[0].')' ];
			$exists->{$user} = 1;
		}

	}

	return [
		{ all_groups   	=> $reply->{all_groups} },
		{ path     	=> $dirs },
		{ file     	=> '' },
		{ users	   	=> \@users },
		{ clear_export	=> 1 },
		{ action   	=> "cancel" },
		{ action   	=> "post_it" }
	];
}

sub post_it
{
	my $this   = shift;
	my $reply  = shift;
	my $file   = $reply->{path}; 
	my @users  = split /\n/, $reply->{users};
	my $exists = {};
	my @groups = split /\n/, $reply->{class};
	push @groups, split /\n/, $reply->{group};

	if( defined $reply->{file}->{content} )
	{
		$file   = '/tmp/'.$reply->{file}->{filename};
		my $tmp = write_tmp_file($reply->{file}->{content});
		system("/usr/bin/base64 -d $tmp >'$file'; rm $tmp;");
	}
	foreach my $g (@groups)
	{
		foreach my $user ( @{$this->get_students_of_group($g)} )
		{
			next if $exists->{$user};
			push @users, $user;
			$exists->{$user} = 1;
		}
	}
	if( $reply->{class_room} )
	{
		my $room = main::GetSessionValue('room');
		my $ws   = $this->get_workstation_users($room);
		push @users, @{$ws};
	}
	if( $reply->{class_room_users} )
	{
		foreach my $ws ( @{$this->get_workstations_of_room(main::GetSessionValue('room'))} )
		{
			my   $u  = $this->get_user_of_workstation($ws);
			push @users, $u if( $u && $this->is_student($u) );
		}
	}
	if( ! -e $file )
	{
		return { TYPE => 'ERROR', CODE => 'no_file', MESSAGE => 'Please choose a file' };
	}
	$this->post_file($file,\@users,$reply->{clear_export},$reply->{clear_home});
	if( defined $reply->{file}->{content} )
	{
		unlink $file;
	}
	my $i = 1;
	my @lines = ( 'users' );
	push @lines, { head => ['#', 'uid', 'user' ]};
	foreach my $dn (@users)
	{
	    my $user_uid  = $this->get_attribute($dn,'uid');
	    my $user_name = $this->get_attribute($dn,'cn');
	    push @lines, { line => [ "$dn",
					{name => 'id', value => "$i", attributes => [ type => 'label', label => '#']},
					{name => 'user_uid', value => "$user_uid", attributes => [ type => 'label']},
					{name => 'user_name', value => "$user_name", attributes => [ type => 'label']},
				]};
	    $i++;
	}
	$file  =~ s#^/tmp/##; 
	return [
		{ label => main::__('post_to').$file },
		{ table  => \@lines },
	]
}
1;
