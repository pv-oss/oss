# LMD GetFile modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package GetFile;

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
		"get_it",
		"openDir"
	];

}

sub getCapabilities
{
	return [
		 { title        => 'Get File' },
		 { type         => 'command' },
		 { order        => 20 },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { allowedRole  => 'teachers' },
		 { allowedRole  => 'teachers,sysadmins' },
		 { category     => 'Students' },
		 { variable     => [ "all_groups",   [ type => "hidden" ] ] },
		 { variable     => [ "clear_export", [ type => "boolean"] ] },
		 { variable     => [ "sort_dir",     [ type => "boolean"] ] },
                 { variable     => [ "users",        [ type => "list", size=>"20", multiple=>"true" ] ] },
                 { variable     => [ "class",        [ type => "list", size=>"5", multiple=>"true" ] ] },
                 { variable     => [ "group",        [ type => "list", size=>"5", multiple=>"true" ] ] }
	];
}

sub openDir
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
	my ( $roles, $classes, $groups ) = $this->get_school_groups_to_search($this->{aDN});
	if( $reply->{all_groups} )
	{
		( $roles, $classes, $groups ) = $this->get_school_groups_to_search();
	}

        my @r = (
                        { all_groups    => $reply->{all_groups} },
                );
        my $room = main::GetSessionValue('room');
        if( $room )
        {
                push @r ,
                { name          => 'class_room',
                  value         => 0,
                  attributes    => [ type => "boolean" , label => main::__('class_room').' '.$room ]
                };
                push @r ,
                { name          => 'class_room_users',
                  value         => 0,
                  attributes    => [ type => "boolean" , label => main::__('class_room_users').' '.$room ]
                };
        }
        push @r, (
                        { class         => $classes },
                        { group         => $groups  },
			{ withsubdir	=> "" },
			{ clear_export	=> 1 },
			{ sort_dir	=> 1 },
                        { action        => "cancel" },
                        { action        => "show_member" },
                        { action        => "all_groups" },
                        { action        => "get_it" }
                );
        return \@r;

}

sub show_member
{
	my $this   = shift;
	my $reply  = shift;
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
		{ users	   	=> \@users },
		{ withsubdir	=> "" },
		{ clear_export	=> 1 },
		{ sort_dir	=> 1 },
		{ action   	=> "cancel" },
		{ action   	=> "get_it" }
	];
}

sub get_it
{
	my $this   = shift;
	my $reply  = shift;
	my @users  = split /\n/, $reply->{users};
	my $exists = {};
	my @groups = split /\n/, $reply->{class};
	push @groups, split /\n/, $reply->{group};

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
	foreach my $g (@groups)
	{
		my $students = $this->get_students_of_group($g);
		foreach my $user ( @{$students} ) {
			next if $exists->{$user};
			push @users, $user;
			$exists->{$user} = 1;
		}
	}
	$this->collect_file(\@users,$reply->{clear_export},$reply->{sort_dir},$reply->{withsubdir});
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
	return [
	    { label => main::__('get_from') },
	    { table  => \@lines },
	]
}
1;
