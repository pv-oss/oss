# OSS LMD AddGroup module
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package AddGroup;

use strict;
use oss_group;
use oss_utils;
use Data::Dumper;

use vars qw(@ISA);
@ISA = qw(oss_group);

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    $connect->{withIMAP} = 1;
    my $self    = oss_group->new($connect);
    return bless $self, $this;
}

sub interface
{
        return [
                "getCapabilities",
                "default",
                "insert"
        ];
}

sub getCapabilities
{
        return [
                { title        => 'Add a new Group' },
                { type         => 'command' },
                { allowedRole  => 'root' },
                { allowedRole  => 'sysadmins' },
                { allowedRole  => 'teachers,sysadmins' },
                { allowedRole  => 'teachers' },
                { category     => 'User' },
		{ order        => 40 },
                { variable     => [ "ownerwriterdn",            [ type => "boolean" ] ] },
                { variable     => [ "web",                      [ type => "boolean" ] ] },
                { variable     => [ "fquota",                   [ type => "string", label => "fquota", backlabel => "MB" ] ] },
                { variable     => [ "quota",                    [ type => "string", label => "quota", backlabel => "MB" ] ] },
                { variable     => [ "susedeliverytofolder",     [ type => "boolean" ] ] },
                { variable     => [ "susedeliverytomember",     [ type => "boolean" ] ] },
		{ variable     => [ "webdav_access",            [ type => "boolean" ] ] },
                { variable     => [ "grouptype",                [ type => "translatedpopup" ] ] }
        ];
}

sub default
{
	my $this  = shift;
	my @ret;
	if( $this->{LDAP_BASE} ne main::GetSessionValue('sdn') )
	{
	       push @ret, { label => main::__( 'Selected School: '). $this->get_attribute(main::GetSessionValue('sdn'),'o') };
	}
	push @ret, { cn => '' };
	push @ret, { description=>'' };
	if( main::GetSessionValue('role') eq 'teachers' )
	{
		push @ret , { name => 'grouptype', value=>'workgroup', attributes => [ type => 'hidden' ] };
	}
	else
	{
		push @ret , { grouptype=> [ 'class' ,'workgroup' , 'primary','---DEFAULTS---','workgroup' ]  };
	}
	push @ret , { ownerwriterdn=>0 };
	push @ret , { web=>0 };
	my $groupquota    = `mount | grep '/home/groups' | grep -q grpquota && echo -n 1 || echo -n 0`;
	push @ret , { fquota => 0 } if ($groupquota) ;
	push @ret , { quota => 0 } ;
	push @ret , { susedeliverytomember => 1 } ;
	push @ret , { susedeliverytofolder => 0 } ;
	push @ret , { webdav_access => 0 } ;
	push @ret , { action => 'cancel' } ;
	push @ret , { action => 'insert' } ;
	return \@ret;
}

sub insert
{
	my $this  = shift;
	my $reply = shift;
	my $role  = main::GetSessionValue('role');

	if( $reply->{grouptype} eq 'workgroup' &&  $role =~ /teachers/ )
	{
		$reply->{member}    = main::GetSessionValue('dn');
		$reply->{memberuid} = get_name_of_dn(main::GetSessionValue('dn'));
	}
	if( $reply->{ownerwriterdn} )
	{
		$reply->{writerdn} = main::GetSessionValue('dn');
	}
	my $dn     = $this->add($reply);
        if( !$dn )
        {
           return {
                TYPE    => 'ERROR',
                CODE    => $this->{ERROR}->{code},
                MESSAGE_NOTRANSLATE => $this->{ERROR}->{text}
           }
        }

        return {
             TYPE     => 'NOTICE',
             MESSAGE1 => $reply->{cn}.' '.$reply->{description},
             MESSAGE  => 'Group was created succesfully'
        };
	
}

1;
