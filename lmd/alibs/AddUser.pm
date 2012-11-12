# LMD AddUser modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package AddUser;

use strict;
use oss_user;
use oss_utils;
use oss_LDAPAttributes;
use Data::Dumper;

use vars qw(@ISA);
@ISA = qw(oss_user);

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    $connect->{withIMAP} = 1;
    my $self    = oss_user->new($connect);
    $self->{RADIUS} = ($self->get_school_config('SCHOOL_USE_RADIUS') eq 'yes') ? 1 : 0;
    return bless $self, $this;
}

sub interface
{
	return [
		"getCapabilities",
		"default",
		"insert",
		"shortAttributes",
		"longAttributes"
	];

}

sub getCapabilities
{
	return [
		{ title        => 'Add a new User' },
		{ type         => 'command' },
		{ allowedRole  => 'root' },
		{ allowedRole  => 'sysadmins' },
		{ allowedRole  => 'teachers,sysadmins' },
		{ category     => 'User' },
		{ order        => 10 },
		{ variable     => [ "admin", 			[ type => "boolean" ] ] },
		{ variable     => [ "alias", 			[ type => "boolean" ] ] },
		{ variable     => [ "mustchange",		[ type => "boolean" ] ] },
		{ variable     => [ "birthday",			[ type => "date" ] ] },
		{ variable     => [ "class",			[ type => "list", size=>"10", multiple=>"true" ] ] },
		{ variable     => [ "group",			[ type => "list", size=>"10", multiple=>"true" ] ] },
		{ variable     => [ "rasaccess",		[ type => "list", size=>"5",  multiple=>"true" ] ] },
		{ variable     => [ "c", 			[ type => "popup" ] ] },
		{ variable     => [ "preferredlanguage",	[ type => "popup" ] ] },
		{ variable     => [ "role",			[ type => "popup" ] ] },
                { variable     => [ "fquota",                   [ type => "string", label => "fquota", backlabel => "MB" ] ] },
                { variable     => [ "quota",                    [ type => "string", label => "quota", backlabel => "MB" ] ] },
		{ variable     => [ "mailenabled",              [ type => "translatedpopup",  ] ] },
		{ variable     => [ "oxtimezone",		[ type => "popup" ] ] },
		{ variable     => [ "webdav_access",            [ type => "boolean" ] ] }
	];
}

sub default
{
	my $this   = shift;
	my $reply  = shift;
	my $uid    	= $reply->{uid} || ''; 
	my $sn          = $reply->{sn} || ''; 
	my $givenname   = $reply->{givenname} || ''; 
	my $userpassword= $reply->{userpassword} || 'system'; 
	my $quota       = $reply->{quota} || ''; 
	my $fquota	= $reply->{fquota} || ''; 
	my $mustchange  = $reply->{mustchange} || 0;
	my $admin	= $reply->{admin}      || 0;
	my $alias       = $reply->{alias}      || 0;
	my $birthday    = $reply->{birthday}   || '';
	my @class       = ( ["all","all"] );
	my @role	= ();
	my @ret;
	if( $this->{LDAP_BASE} ne main::GetSessionValue('sdn') )
	{
	       push @ret, { label => main::__( 'Selected School: '). $this->get_attribute(main::GetSessionValue('sdn'),'o') };
	}
        my ( $primaries, $classes, $workgroups ) = $this->get_school_groups_to_search();
        foreach my $i ( @{$primaries} )
        {
            my $dn  = shift @{$i};
            my $r   = $this->get_attribute($dn,'role');
            my $d   = $this->get_attribute($dn,'description') || main::__($r);
            next if ( $r eq 'workstations' );
            push @role, [ $r , $d ];
        }
        push @role, '---DEFAULTS---' , 'students';
	push @class, @{$classes};
       
	push @ret, { uid	      => $uid };
	push @ret, { sn	      => $sn };
	push @ret, { givenname   => $givenname };
	push @ret, { userpassword=> $userpassword };
	push @ret, { mustchange  => $mustchange };
	push @ret, { alias       => $alias };
	push @ret, { birthday    => $birthday };
	push @ret, { role        => \@role};
	push @ret, { class       => \@class };
	push @ret, { quota	      => $quota };
	push @ret, { fquota      => $fquota };
	push @ret, { preferredlanguage => getLanguages(main::GetSessionValue('lang')) };
	push @ret, { mailenabled => \@mailEnabled };
	push @ret, { admin       => $admin };
	push @ret, { webdav_access => 0 };
	push @ret, { rasaccess  => $this->get_wlan_workstations } if ( $this->{RADIUS} );
	push @ret, { action   => "cancel" };
	push @ret, { action   => "insert" };
	return \@ret;
}

sub shortAttributes
{
	my $this   = shift;
	my $reply  = shift;
	$this->default($reply);
}

sub longAttributes
{
	my $this   = shift;
	my $reply  = shift;
	my $uid    	= $reply->{uid} || ''; 
	my $sn          = $reply->{sn} || ''; 
	my $givenname   = $reply->{givenname} || ''; 
	my $userpassword= $reply->{userpassword} || ''; 
	my $quota       = $reply->{quota} || ''; 
	my $fquota	= $reply->{fquota} || ''; 
	my $mustchange  = $reply->{mustchange} || 0;
	my $admin	= $reply->{admin}      || 0;
	my $alias       = $reply->{alias}      || 0;
	my $birthday    = $reply->{birthday}   || '';
	my @role	= ();
	my @class       = ( ["all","all"] );
        my ( $primaries, $classes, $workgroups ) = $this->get_school_groups_to_search();
        foreach my $i ( @{$primaries} )
        {
            my $dn  = shift @{$i};
            my $r   = $this->get_attribute($dn,'role');
            next if ( $r eq 'workstations' );
            push @role, $r;
        }
        push @role, [ '---DEFAULTS---' ], [ 'students' ];
	push @class, @{$classes};

	return [
		{ uid	      => $uid },
		{ sn	      => $sn },
		{ givenname   => $givenname },
		{ userpassword=> $userpassword },
		{ mustchange  => $mustchange },
		{ birthday    => $birthday },
		{ role        => \@role },
		{ class       => \@class },
		{ group       => $workgroups },
		{ quota	      => $quota },
		{ fquota      => $fquota },
		{ preferredlanguage => getLanguages(main::GetSessionValue('lang')) },
		{ admin       => $admin },
		{ webdav_access => 0 },
		{ oxtimezone  => getTimeZones() },
		{ action   => "shortAttributes" },
		{ action   => "insert" }
	];
}

sub insert
{
	my $this   = shift;
	my $reply  = shift;

	make_array_attributes($reply);
	my $dn     = $this->add($reply);
        if( defined $reply->{class} )
        {
            if( $reply->{class}->[0] eq 'all' )
            {
                $reply->{ou} = 'all';
            }
            else
            {
                my @classes = ();
                foreach my $class ( @{$reply->{class}} )
                {
                    push @classes, get_name_of_dn($class);
                }
                $reply->{ou} = join(" ",@classes);
            }
        }
	if( !$dn )
	{
	   return {
	   	TYPE    => 'ERROR',
	   	CODE    => $this->{ERROR}->{code},
		MESSAGE_NOTRANSLATE => $this->{ERROR}->{text}
	   }
	}

	my $user = $this->get_user($dn,['uid','cn','description']);
	return {
	     TYPE                 => 'NOTICE',
	     MESSAGE1_NOTRANSLATE => $user->{cn}->[0].',  '.$user->{uid}->[0].', ('.$user->{description}->[0].')',
	     MESSAGE              => 'User was created succesfully'
	};
}

1;
