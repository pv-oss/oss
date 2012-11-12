=head1 NAME
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

 oss_pedagogic

=head1 PREFACE

 This package is the public perl API to the pedadogical functions of the OpenSchoolServer.

=head1 SYNOPSIS

 #!/usr/bin/perl 
 
 BEGIN{ push @INC,"/usr/share/oss/lib/"; }
 
 use oss_pedagogic;

 my $oss = oss_pedagogic->new();
 
 $oss->post_file('/home/teachers/bigbos/Documents/Works/BigWork', [ 'uid=micmou,ou=people,dc=schule,dc=de' ]);

=head1 DESCRIPTION

B<oss_pedagogical>  is a collection of pedagogical functions of the OpenSchoolServer. 

=over 2

=cut

BEGIN{
  push @INC,"/usr/share/oss/lib/";
}

package oss_pedagogic;

use strict;
use oss_base;
use oss_utils;
use Net::LDAP;
use Net::LDAP::Entry;
use utf8;
use Encode ( 'encode', 'decode' );

use vars qw(@ISA);
@ISA = qw(oss_base);
#-----------------------------------------------------------------------

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    my $self    = oss_base->new($connect);
    return bless $self, $this;
}
#-----------------------------------------------------------------------

=item B<post_file(File,Users|Groups,[clean up])>

B<File> is the full path to the file or directory must be copied.

B<Users|Groups> is a pointer to a list of dns of groups or users. The list can be a mix of user and group dns.

B<clean up> is defaultly 1 and has different meaning for workstation users as for normal users. 
In the case of workstation users the whole homedirectory and windows profiles will be reseted.
By students only Export and Import will be cleaned up.

=cut
sub post_file
{
    my $this    = shift;
    my $file	= shift;
    my $users	= shift;
    my $clear_export	= shift;
    my $clear_home	= shift;
    my @users   = ();

    foreach my $dn ( @{$users} )
    {
        my $attributes = $this->get_attributes($dn,['homedirectory','uidnumber','gidnumber']);
	my $home       = $attributes->{homedirectory}->[0];
	my $Export     = $home.'/Export';
	my $Import     = $home.'/Import';
	if( $clear_home && $this->is_workstation($dn) )
	{
		my $homebase = $this->{SYSCONFIG}->{SCHOOL_HOME_BASE} || '/home';
		my $skel     = "/etc/skel/";
		if( -d "$homebase/templates/tworkstations" )
		{
		   $skel = "$homebase/templates/tworkstations/";
		}
		my $profile = $homebase.'/profile/'.get_name_of_dn($dn); 
		my $command = "rsync -a --delete  $skel ".$home."/;";
		$command .= "chown   -R ".$attributes->{uidnumber}->[0].':'.$attributes->{gidnumber}->[0].' '.$home.';';
		$command .= "chmod 770 ".$home.';';
		$command .= "test -e $profile && rm -rf $profile ;";
		$command .= "mkdir $profile;";
		$command .= "test -d $homebase/profile/tworkstations && rsync -a $homebase/profile/tworkstations/ $profile/;";
		$command .= "chmod -R 700 $profile; chown -R ".$attributes->{uidnumber}->[0].':'.$attributes->{gidnumber}->[0]." $profile;";
		system($command);
	}
	elsif( $clear_export )
	{
	    system("test -e $Export && rm -rf $Export; test -e $Import && rm -rf $Import;")
	}
	system("mkdir -p $Export $Import; cp -a '$file' $Import; chown -R ".$attributes->{uidnumber}->[0].':'.$attributes->{gidnumber}->[0]." $Export $Import;" );
    }
}
#-----------------------------------------------------------------------

=item B<collect_file(From,Sortdir,[Subdir])>


=cut

sub collect_file
{
    my $this         = shift;
    my $users        = shift;
    my $clear_export = shift;
    my $sortdir	     = shift;
    my $subdir	     = shift || '';

    my $attributes = $this->get_attributes($this->{aDN},['homedirectory','uidnumber','gidnumber']);
    my $target     = $attributes->{homedirectory}->[0].'/Import/'.$subdir;
    system("mkdir -p -m 700 '$target';");

    foreach my $dn ( @{$users} )
    {
        my $uid     = $this->get_attribute($dn,'uid');
        my $home    = $this->get_attribute($dn,'homedirectory');
	my $command = '';
    	if( $sortdir )
	{
	   $command  = "mkdir -p -m 700 '$target/$uid';\n";
	   $command .= "cp -a $home/Export/* '$target/$uid';\n";
	}
	else
	{
	   foreach( glob("$home/Export/*") )
	   {
	      my $t = decode('UTF-8',$_);
	      $t =~ /$home\/Export\/(.*)/; 
	      $command .= "cp '$t' '$target/$uid-$1';\n";
	   }
	}
	if( $clear_export )
	{
	   $command .= "rm -r $home/Export/* ;\n";
	}
	system($command);
	print $command if ( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' );
    }
    system('chown   -R '.$attributes->{uidnumber}->[0].':'.$attributes->{gidnumber}->[0]." '$target' ;");
}
#-----------------------------------------------------------------------

=item B<get_whitelist_categories([CategoryDN])>

=cut

sub get_whitelist_categories
{
    my $this    = shift;
    my $base	= shift || 'ou=WhiteLists,'.$this->{SCHOOL_BASE};

    my $result = $this->{LDAP}->search( base  => $base, 
					scope => 'one',
					filter=>'(objectclass=organizationalUnit)',
					attrs => [ 'description','ou'] );
    if( $result->code )
    {
	$this->ldap_error($result);
	return undef;
    }
    if( ! $result->count )
    {
	$this->{ERROR} = "No White List exists";
	return undef;
    }
    return $result->as_struct;
}
#-----------------------------------------------------------------------

=item B<get_whitelists([CategoryDN])>

=cut

sub get_whitelists
{
    my $this    = shift;
    my $base	= shift || 'ou=WhiteLists,'.$this->{SCHOOL_BASE};

    my $result = $this->{LDAP}->search( base  => $base, 
					scope => 'one',
					filter=>'(objectclass=WhiteList)',
					attrs => [ 'description','cn'] );
    if( $result->code )
    {
	$this->ldap_error($result);
	return undef;
    }
    if( ! $result->count )
    {
	$this->{ERROR} = "No White List exists";
	return undef;
    }
    return $result->as_struct;
}
#-----------------------------------------------------------------------

=item B<add_whitelist_category(Category,Description,[Base])>

=cut

sub add_whitelist_category
{
    my $this    = shift;
    my $cat	= shift;
    my $desc	= shift;
    my $base    = shift || 'ou=WhiteLists,'.$this->{SCHOOL_BASE};
    my $dn      = 'ou='.$cat.','.$base;

    my $result =$this->{LDAP}->add( dn => $dn,
                                attrs =>
                                        [
                                                objectClass  => 'organizationalUnit',
						description  => $desc,
                                                ou           => $cat
                                        ]
                                );
    if( $result->code )
    {
	$this->ldap_error($result);
	return undef;
    }
    return $dn;
}
#-----------------------------------------------------------------------

=item B<add_whitelist($CategoryDN,$Name,$Description,[\@WhiteList])>

=cut

sub add_whitelist
{
    my $this    = shift;
    my $base	= shift;
    my $cn      = shift;
    my $desc	= shift;
    my $list	= shift || undef;
    my $dn      = 'cn='.$cn.','.$base;

    my $result =$this->{LDAP}->add( dn => $dn,
                                attrs =>
                                        [
                                                objectClass  => 'WhiteList',
						description  => $desc,
                                                cn           => $cn
                                        ]
                                );
    if( $result->code )
    {
	$this->ldap_error($result);
	return undef;
    }
    if( $list )
    {
	$result =$this->{LDAP}->modify( $dn, add => { allowedDomain => $list });
    }
    if( $result->code )
    {
	$this->ldap_error($result);
	return undef;
    }
}

#-----------------------------------------------------------------------

=item B<activate_whitelist(whiteListDN,RoomDN,ownIP)

Activates a white list in a room. The white list does not apply to ownIP

=cut

sub activate_whitelist
{
	my $this = shift;
	my $wl	 = shift;
	my $room = shift;
	my $IP	 = shift;
	my $ws   = $this->get_workstations_of_room($room);
	my @IPS  =();

	foreach( @{$this->get_workstations_of_room($room)} )
	{
		my $i = $this->get_ip_of_host($_);
		next if( $IP eq $i );
		push @IPS, $i;	
	}
	#Is this a white list categorie
	if( ! $this->is_white_list( $wl ) )
	{
		my $res  = $this->{LDAP}->search( base  => $wl,
						 scope  => 'sub',
						 filter => '(objectClass=whiteList)',
					     attributes => [ 'dn' ] );
		foreach my $entry ( $res->entries )
		{
			$this->{LDAP}->modify( $entry->dn , add => { activatedIP => \@IPS } );
			$this->add_value_to_vendor_object($room,'oss','whiteLists',$entry->dn);
		}
	}
	else
	{
		$this->{LDAP}->modify( $wl , add => { activatedIP => \@IPS } );
		$this->add_value_to_vendor_object($room,'oss','whiteLists',$wl);
	}
}
#-----------------------------------------------------------------------

=item B<deactivate_whitelist(whiteListDN,RoomDN,ownIP)

=cut

sub deactivate_whitelist
{
	my $this = shift;
	my $wl	 = shift;
	my $room = shift;
	my $IP	 = shift;
	my $ws   = $this->get_workstations_of_room($room);
	my @IPS  = ();

	foreach( @{$this->get_workstations_of_room($room)} )
	{
		my $i = $this->get_ip_of_host($_);
		next if( $IP eq $i );
		push @IPS, $i;	
	}
	if( ! $this->is_white_list( $wl ) )
	{
		my $res  = $this->{LDAP}->search( base  => $wl,
						 scope  => 'sub',
						 filter => '(objectClass=whiteList)',
					     attributes => [ 'dn' ] );
		foreach my $entry ( $res->entries )
		{
			$this->{LDAP}->modify( $entry->dn , delete => { activatedIP => \@IPS } );
			$this->delete_value_from_vendor_object($room,'oss','whiteLists',$entry->dn);
		}
		$this->delete_value_from_vendor_object($room,'oss','whiteLists',$wl);
	}
	else
	{
		$this->{LDAP}->modify( $wl , delete => { activatedIP => \@IPS } );
		$this->delete_value_from_vendor_object($room,'oss','whiteLists',$wl);
	}
}
#-----------------------------------------------------------------------

=item B<is_white_list(DN)>

Checks if the the DN a white list is

=cut

sub is_white_list($)
{
	my $this = shift;
	my $dn	 = shift;
	my $res  = $this->{LDAP}->search( base  => $dn,
					 scope  => 'base',
					 filter => '(objectClass=whiteList)',
				     attributes => [ 'dn' ] );
	if( defined $res && $res->count )
	{
		return 1;
	}
	return 0;
}
