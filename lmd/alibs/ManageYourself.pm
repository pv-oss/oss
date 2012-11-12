# LMD ManageYourself modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ManageYourself;

use strict;
use oss_user;
use oss_LDAPAttributes;
use oss_utils;
use vars qw(@ISA);
@ISA = qw(oss_user);
use Data::Dumper;

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    $connect->{withIMAP} = 1;
    my $self    = oss_user->new($connect);
    return bless $self, $this;
}

sub interface
{
	return [
		"getCapabilities",
		"default",
		"setChanges"
	];

}

sub getCapabilities
{
	return [
		{ title        => 'Settings' },
		{ type         => 'command' },
		{ allowedRole  => 'root' },
		{ allowedRole  => 'sysadmins' },
		{ allowedRole  => 'teachers' },
		{ allowedRole  => 'teachers,sysadmins' },
		{ category     => 'Settings' },
                { order        => 20 },
                { variable     => [ "dn",                       [ type => "hidden" ] ] },
                { variable     => [ "users",                    [ type => "list", size=>"20", multiple=>"true" ] ] },
                { variable     => [ "class",                    [ type => "list", size=>"10", multiple=>"true" ] ] },
                { variable     => [ "group",                    [ type => "list", size=>"10", multiple=>"true" ] ] },
                { variable     => [ "role",                     [ type => "list", size=>"6", multiple=>"true" ] ] },
                { variable     => [ "uid",                      [ type => "label"  ] ] },
                { variable     => [ "sn",                       [ type => "label"  ] ] },
                { variable     => [ "givenname",                [ type => "label"  ] ] },
                { variable     => [ "birthday",                 [ type => "date",  ] ] },
                { variable     => [ "mail",                     [ type => "popup"  ] ] },
                { variable     => [ "preferredlanguage",        [ type => "popup"  ] ] },
                { variable     => [ "fquota",                   [ type => "label" ] ] },
		{ variable     => [ "fquotaused",               [ type => "label" ] ] },
                { variable     => [ "quota",                    [ type => "label" ] ] },
		{ variable     => [ "quotaused",                [ type => "label" ] ] },
                { variable     => [ "oxtimezone",               [ type => "popup" ] ] },
                { variable     => [ "susedeliverytofolder",     [ type => "boolean" ] ] },
                { variable     => [ "susemailforwardaddress",   [ type => "list", label => "susemailforwardaddress", help => 'Select Entry to delete', size=>"5", multiple=>"true" ] ] },
                { variable     => [ "susemailacceptaddress",    [ type => "list", label => "susemailacceptaddress", help => 'Select Entry to delete', size=>"5", multiple=>"true"] ] }

	];
}

sub default
{
	my $this    = shift;
	my $user   = $this->get_user(main::GetSessionValue('dn') ,\@userAttributeList);
	my @ret	    = ();
        foreach my $attr ( @userAttributeList )
        {
		next if( ! main::isAllowed('ManageYourself.default.'.$attr) );
                my $val = undef;
                if( defined $user->{$attr} )
                {
                        if( $attr eq 'mail' )
                        {
				next if ( !defined $user->{susemailacceptaddress} );
                                my @tmp = ( @{$user->{susemailacceptaddress}} , '---DEFAULTS---' , $user->{$attr}->[0] );
                                $val = \@tmp ;
                        }
                        elsif( $attr eq 'susedeliverytofolder' )
                        {
				if( defined $user->{$attr} )
				{
                                	$val = $user->{$attr}->[0] eq "yes" ? 1:0;
				}
				else
				{
					$val = 1;
				}
                        }
                        elsif( $attr =~ /^susemail.*address$/ )
                        {
                                $val =  $user->{$attr};
                        }
                        elsif( $attr =~ /^preferredlanguage$/ )
                        {
                                $val =  getLanguages($user->{$attr}->[0]);
                        }
                        elsif( $attr =~ /^oxtimezone$/ )
                        {
                                $val =  getTimeZones($user->{$attr}->[0]);
                        }
			elsif( $attr =~ /quota/ )
			{
				$val = $user->{$attr}->[0]." MB";
			}
                        else
                        {
                                $val = join '', @{$user->{$attr}};
                        }
                }
                push @ret, { $attr => $val };
                if( $attr =~ /^susemailacceptaddress$/ )
                {
                        push @ret, { newsusemailacceptaddress => '' };
                }
                if( $attr =~ /^susemailforwardaddress$/ )
                {
                        push @ret, { newsusemailforwardaddress => '' };
                }
        }
        push @ret, { action       => "cancel" };
        push @ret, { name => 'action', value => "setChanges", attributes => [ label => 'apply' ]  };
        return \@ret;

}

sub setChanges
{
	my $this   = shift;
	my $reply  = shift;
	$reply->{dn} = main::GetSessionValue('dn');

	#TODO students may not modify himself
        make_array_attributes($reply);
	$reply->{susedeliverytofolder} = $reply->{susedeliverytofolder} ? "yes" : "no";
        if( ! $this->modify($reply) )
        {
                return {
                     TYPE    => 'ERROR',
                     CODE    => $this->{ERROR}->{code},
                     MESSAGE_NOTRANSLATE => $this->{ERROR}->{text}
                }
        }

	$this->default();
}

1;
