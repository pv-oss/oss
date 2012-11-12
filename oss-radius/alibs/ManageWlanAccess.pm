# LMD ManageWlanAccess modul
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ManageWlanAccess;

use strict;
use oss_base;
use oss_utils;

use vars qw(@ISA);
@ISA = qw(oss_base);

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    $connect->{withIMAP} = 1;
    my $self    = oss_base->new($connect);
    $self->{RADIUS} = ($self->get_school_config('SCHOOL_USE_RADIUS') eq 'yes') ? 1 : 0;
    return bless $self, $this;
}

sub interface
{
        return [
                "default",
                "apply"
        ];

}

sub getCapabilities
{
        return [
                { title        => 'Managing the Wlan Workstations' },
                { type         => 'command' },
                { allowedRole  => 'root' },
                { allowedRole  => 'sysadmins' },
                { allowedRole  => 'teachers,sysadmins' },
                { category     => 'Network' },
                { order        => 90 },
                { variable     => [ "class",                    [ type => "list", size=>"5",  multiple=>"true" ] ] },
                { variable     => [ "workgroup",                [ type => "list", size=>"5",  multiple=>"true" ] ] },
                { variable     => [ "role",                     [ type => "list", size=>"5",  multiple=>"true" ] ] },
                { variable     => [ "rasaccess",                [ type => "list", size=>"10", multiple=>"true" ] ] }
	];
}

sub default
{
	my $this   = shift;
        my $reply  = shift;
        my @ret    = ( { subtitle    => 'Select Workstations and Groups' } );
        my ( $roles, $classes, $workgroups ) = $this->get_school_groups_to_search();
        if( $this->{LDAP_BASE} ne main::GetSessionValue('sdn') )
        {
               push @ret, { label => main::__( 'Selected School: '). $this->get_attribute(main::GetSessionValue('sdn'),'o') };
        }
        push @ret, { role        => $roles};
        push @ret, { class       => $classes };
        push @ret, { workgroup   => $workgroups };
        push @ret, { rasaccess   => $this->get_wlan_workstations };
	push @ret, { rightaction => 'cancel' };
	push @ret, { rightaction => 'apply' };
	return \@ret;
}

sub apply
{
	my $this   = shift;
        my $reply  = shift;
        my @role        = split /\n/, $reply->{role}  || ();
        my @group       = split /\n/, $reply->{workgroup} || ();
        my @class       = split /\n/, $reply->{class} || ();
        my @rasaccess   = split /\n/, $reply->{rasaccess} || ();
	my $result      = main::__('Wlan Access set for User: ');


	my $user        = $this->search_users('*',\@class,\@group,\@role);
	foreach my $dn ( sort keys %{$user} )
        {
		$result .= $this->get_attribute($dn,'cn').'; ';	
		$this->{LDAP}->modify( $dn , delete => { rasaccess => [] } );
		$this->{LDAP}->modify( $dn , add    => { rasaccess => \@rasaccess } );
	}
	return [
		{ notranslate_label => $result },
		{ notranslate_label => join("; ", @rasaccess) },
		{ name => 'action', value => 'default', attributes => [ label => 'back' ] } 
	]
}

