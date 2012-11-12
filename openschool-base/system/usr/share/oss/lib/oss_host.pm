=head1 NAME
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

 oss_host

=head1 PREFACE

 This package is the public perl API to configure the OpenSchoolServer.

=head1 SYNOPSIS

 #!/usr/bin/perl 
 
 BEGIN{ push @INC,"/usr/share/oss/lib/"; }
 
 use oss_host;

 my $oss_host = oss_host->new();
 
 $oss_host->delete('mediothek-pc06');

Or the host can be given by the DN of the corresponding DHCP entry.

 $oss_host->delete('cn=mediothek-pc06,cn=Room1,cn=172.16.0.0,cn=config1,cn=admin,ou=DHCP,dc=schule,dc=de');

=head1 DESCRIPTION

B<oss_host>  is a collection of functions that implement a OpenSchoolServer 
configuration API for Perl programs to add, modify, search and delete host.

=over 2

=cut

BEGIN{
  push @INC,"/usr/share/oss/lib/";
}

package oss_host;

use strict;
use oss_user;
use oss_utils;
use oss_LDAPAttributes;
use Net::LDAP;
use Net::LDAP::Entry;

use vars qw(@ISA);
@ISA = qw(oss_user);

#-----------------------------------------------------------------------

sub new
{
    my $this = shift;
    my $self = oss_user->new();
    if( $self->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' ) 
    {
       use Data::Dumper;
    }
    return bless $self, $this;
}
#-----------------------------------------------------------------------

=item B<add(hostHash)>

Create a new host. To create a new host means to create following objects:

   * dhcp entry.
   * 2 DNS entries A-Record & P-Record.
   * samba workstation account. 
   * workstation user account.
   * if necessary name aliases.

IMPORTANT: The hash keys must be in lower case.

EXAMPLE:

   $oss_user->add(      name => 'mediothek-pc01', 
		      domain => 'schule.de',
                      roomdn => 'cn=Room1,cn=172.16.0.0,cn=config1,cn=admin,ou=DHCP,dc=schule,dc=de',
		   hwaddress => '00:04:23:CF:F8:2D',
		   ipaddress => '172.16.5.10',
		      hwconf => hwconf1,
		      master => yes
                );

=cut

sub add($)
{
    my $this  = shift;
    my $HOST  = shift;
    my $ERROR = "";


    $ERROR = $this->check_host_attributes($HOST);
    if( $ERROR ne "" )
    {
        $this->{ERROR}->{CODE} = "BAD-HOST-PARAMETERS";
	$this->{ERROR}->{TEXT} = $ERROR;
	return undef;
    }

    #There is a school defined
    if( defined $HOST->{oid} )
    {
        $this->init_sysconfig($this->get_school_base($HOST->{oid}));
    }
    if( defined $HOST->{sDN} )
    {
        $this->init_sysconfig($HOST->{sDN});
    }

    my @hostDNs = $this->add_host_to_dns($HOST->{name}.'.'.$HOST->{domain},$HOST->{ipaddress});
    if( defined $HOST->{alternate} )
    {
       push @hostDNs, $this->add_host_to_zone($HOST->{alternate}.'.'.$HOST->{domain},$HOST->{ipaddress});
       @hostDNs = normalize(@hostDNs);
    }
    
    my $DN   = 'cn='.$HOST->{name}.','.$HOST->{roomdn};
    $HOST->{dn}  = $DN;

    my $DHCPEntry = Net::LDAP::Entry->new();
    $DHCPEntry->dn($DN);

    $DHCPEntry->add( cn => $HOST->{name} );
    foreach my $hostDN ( @hostDNs )
    {
        $DHCPEntry->add( dNSZoneDN => $hostDN );
	$this->{LDAP}->modify( $hostDN, add => { objectClass => 'DHCPEntry' , dhcpHostDN => $DN } );
    }
    $DHCPEntry->add( dhcpStatements => 'fixed-address '.$HOST->{ipaddress} );
    $DHCPEntry->add( dhcpHWAddress  => 'ethernet '.$HOST->{hwaddress} );
    $DHCPEntry->add( objectClass => ['top','dhcpHost','dhcpOptions','DHCPEntry','SchoolWorkstation'] );
    if( defined $HOST->{hwconf} )
    {
        $DHCPEntry->add( configurationValue => 'HW='.$HOST->{hwconf} );
    }
    if( defined $HOST->{master} )
    {
        $DHCPEntry->add( configurationValue => 'MASTER='.$HOST->{master} );
    }
    my $mesg = $this->{LDAP}->add($DHCPEntry);
    if( $mesg->code() )
    {
        $this->ldap_error($mesg);
        return 0;
    }

    my $USER = {};

    $USER->{userpassword} = $USER->{uid} = $HOST->{name};
    $USER->{sn}   = $HOST->{name}.' Workstation-User';
    $USER->{role} = 'workstations';

    if( ! $this->SUPER::add($USER) )
    {
    	if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' )
	{
	   print Dumper($USER);
	}
	print STDERR $this->{ERROR}->{text};
	print STDERR $this->{ERROR}->{code};
    }	

    my $WS = {};
    $WS->{sn} = $WS->{cn} = $WS->{uid} = $HOST->{name}.'$';
    $WS->{uidnumber} = $this->get_next_unique('user');
    $WS->{description} = 'Workstation account ip:'.$HOST->{ipaddress};
    $WS->{dn}  = 'uid='.$WS->{uid}.','.$this->{SYSCONFIG}->{COMPUTERS_BASE};

    $this->set_samba_attributes($WS);

    my $WSEntry = Net::LDAP::Entry->new();
    $WSEntry->dn($WS->{dn});

    foreach my $i ( keys %defaultWorkstation )
    {
       if( defined $WS->{$i} )
       {
	  $WSEntry->add( $i => $WS->{$i} );
       }
       else
       {
          $WS->{$i} = $defaultWorkstation{$i};
	  $WSEntry->add( $i => $defaultWorkstation{$i} );
       }
    }
    $mesg = $this->{LDAP}->add($WSEntry);
    if( $mesg->code() )
    {
    	if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' )
	{
	   print Dumper($WS);
	}
        $this->ldap_error($mesg);
        return 0;
    }
    return 1;
}


=item B<delete(dn)>

Delets a workstation. The workstation will be given by the dn in the 
DHCP configuration.

EXAMPLE:

  $oss_host->delete($DHCP_DN_OF_A_WS|Name_of_a_WS);

=cut

sub delete($) 
{
    my $this = shift;
    my $dn   = shift;
    my $name = get_name_of_dn($dn);

    # Now we delete the entry from the corresponding DNS-forward-lookup entry
    my $result = $this->{LDAP}->search(  base    => $this->{SYSCONFIG}->{DNS_BASE},
                                         filter  => "dhcpHostDN=$dn",
                                         attrs   => ['dn']
                           );
    foreach my $entry ($result->entries)
    {
        $this->{LDAP}->delete($entry->dn());
    }

    # Now we delete the entry from the corresponding DNS-revers-lookup entry
    $result = $this->{LDAP}->search(  base    => $this->{SYSCONFIG}->{DNS_BASE},
                                      filter  => "pTRRecord=$name.*",
                                      attrs   => ['dn']
                           );
    foreach my $entry ($result->entries)
    {
        $this->{LDAP}->delete($entry->dn());
    }

    #Now we delete the workstation user and the samba workstation entry
    $result = $this->{LDAP}->search(  base    => $this->{SYSCONFIG}->{USER_BASE},
                                      filter  => "uid=$name",
                                      attrs   => ['dn','homedirectory']
                           );
    foreach my $entry ($result->entries)
    {
	my $home = $entry->get_value('homedirectory');
	my $prof = $this->{SYSCONFIG}->{SCHOOL_HOME_BASE}.'/profile/'.$name;
	system("test -d $home && rm -rf $home &> /dev/null");
	system("test -d $prof && rm -rf $prof &> /dev/null");
        $this->{LDAP}->delete($entry->dn());
    }

    $result = $this->{LDAP}->search(  base    => $this->{SYSCONFIG}->{COMPUTERS_BASE},
                                      filter  => "uid=$name\$",
                                      attrs   => ['dn']
                           );
    foreach my $entry ($result->entries)
    {
        $this->{LDAP}->delete($entry->dn());
    }

    # Now we delete the DHCP-entry
    $this->{LDAP}->delete($dn);

    return 1;
}

=item B<check_host_attributes($MY_OST)>

This subroutine checks the parameters of a host hash:

1. Are name and alias OK & unique.
2. Are HW-Address and IP-Address OK and unique?

=cut
sub check_host_attributes($)
{
    my $this  = shift;
    my $HOST  = shift;
    my $ERROR = '';

    my $filter = '(cn='.$HOST->{name}.')';
    if( defined $HOST->{alternate} )
    {
       $filter = '(|'.$filter.'(cn='.$HOST->{alternate}.'))';
    }

    my $result = $this->{LDAP}->search(  base    => $this->{SYSCONFIG}->{DNS_BASE},
    					 filter  => $filter
                                         attrs   => ['dn']
					 );					 
    if( defined $result->count && $result->count > 0 )
    {
       "Host name allready used by ".$result->entry(0)->dn."\n"; 
    }
    return $ERROR;	
}
