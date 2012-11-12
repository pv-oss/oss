# LMD changePassword modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package changePassword;

use strict;
use oss_base;
use oss_LDAPAttributes;
use oss_utils;
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
		{ title        => 'change_passwd' },
		{ type         => 'command' },
		{ allowedRole  => 'root' },
		{ allowedRole  => 'sysadmins' },
		{ allowedRole  => 'teachers' },
		{ allowedRole  => 'teachers,sysadmins' },
		{ allowedRole  => 'students' },
		{ category     => 'Settings' },
                { order        => 10 },
                { variable     => [ "old_pass",  [ type => "password" ] ] },
                { variable     => [ "new_pass",  [ type => "password" ] ] },
                { variable     => [ "new2_pass", [ type => "password" ] ] }
	];
}

sub default
{
	my $this    = shift;

	my $may_not_change_password_val = $this->get_vendor_object(main::GetSessionValue('dn'), 'EXTIS', 'MayNotChangePassword');
	my $u = $this->get_attributes(main::GetSessionValue('dn'),[ 'cn','shadowmin','shadowmax' ] );
        if( defined $u->{shadowmin}->[0] && defined $u->{shadowmax}->[0] && ( $u->{shadowmin}->[0] > $u->{shadowmax}->[0] ) )
        {
		return [
			{ NOTICE => main::__('Password change is denied. Having problems with your current password contact your administrator or teacher for help!') }
		];
	}

	return [
		{ old_pass  => '' },
		{ new_pass  => '' },
		{ new2_pass => '' },
		{ action    => 'cancel' },
		{ action    => 'set' }
	];
}

sub set
{
	my $this   = shift;
	my $reply  = shift;
	my $dn     = main::GetSessionValue('dn');

	if( $reply->{old_pass} ne main::GetSessionValue('userpassword') )
	{
		return {
			TYPE => 'ERROR',
			CODE => 'change_pw_failed',
			MESSAGE => 'change_pw_failed'
		};
	}
	if( $reply->{new_pass} ne $reply->{new2_pass} )
	{
		return {
			TYPE => 'ERROR',
			CODE => 'new_passwds_not_equal',
			MESSAGE => 'new_passwds_not_equal'
		};
	}
	if( $reply->{new_pass} eq $reply->{old_pass} )
	{
		return {
			TYPE => 'ERROR',
			CODE => 'old_equals_new',
			MESSAGE => 'old_equals_new'
		};
	}
	if( $this->set_password($dn,$reply->{new_pass},0,0,'smd5') )
	{
                return {
                     TYPE    => 'NOTICE',
                     CODE => 'change_passwd_success',
                     MESSAGE => 'change_passwd_success'
                }
	}
	else
	{
                return {
                     TYPE    => 'ERROR',
                     CODE    => $this->{ERROR}->{code},
                     MESSAGE_NOTRANSLATE => $this->{ERROR}->{text}
                }
	}
}

1;
