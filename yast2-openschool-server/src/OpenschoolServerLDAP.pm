#!/usr/bin/perl -w

=head1 NAME

OpenschoolServerLDAP

=head1 PREFACE

This package is a part of the YaST2 mail modul.

=head1 SYNOPSIS

use OpenschoolServerLDAP


=head1 DESCRIPTION

B<OpenschoolServerLDAP>  provides a function ConfigureLDAPServer that makes the local
LDAP server able to store the datas of the Open School Server.

=over 2

=cut

use strict;

package OpenschoolServerLDAP;

use YaST::YCP qw(:LOGGING);
use Data::Dumper;

our %TYPEINFO;

YaST::YCP::Import ("YaPI::LdapServer");
YaST::YCP::Import ("Ldap");


BEGIN {$TYPEINFO{ConfigureLDAPServer} = ["function",  "any" ];}
sub ConfigureLDAPServer
{
    y2milestone("-----Start OSS ConfigureLDAPServer----");
    YaPI::LdapServer->Init();
    my $ldapMap  = YaPI::LdapServer->ReadDatabaseList();
    my $suffix   = $ldapMap->[2]->{'suffix'};
    # Now we configure the LDAP-Server to be able store the mail server configuration
    my $schemas = YaPI::LdapServer->ReadSchemaList();
    my $SCHEMA  = join "",@{$schemas};
    my @RSCHEMAS= qw(   dhcp
			openxchange
			phpgwaccount
			phpgwcontact
			samba3
			openschool-server
		);
    system("cp /usr/share/doc/packages/dhcp-server/dhcp.schema /etc/openldap/schema/");
    foreach my $s (@RSCHEMAS)
    {
        if( -e "/etc/openldap/schema/$s.schema.in" )
	{
	    system( "cp /etc/openldap/schema/$s.schema.in /etc/openldap/schema/$s.schema" );
	}
	if( $SCHEMA !~ /$s/ )
	{
	    YaPI::LdapServer->AddSchema("/etc/openldap/schema/$s.schema");
	}
    }

    # Setup us as ldap client
    Ldap->Read();
    Ldap->LDAPInit();
    my $ldapc = Ldap->Export();
    
    $ldapc->{start_ldap}  = YaST::YCP::Boolean (1);;
    $ldapc->{create_ldap} = YaST::YCP::Boolean (1);;
    $ldapc->{ldap_server} = 'localhost';
    $ldapc->{ldap_domain} = $suffix;
    $ldapc->{base_config_dn} = "ou=ldapconfig,$suffix";
    $ldapc->{bind_dn} = "cn=Administrator,$suffix";
    $ldapc->{file_server} = YaST::YCP::Boolean (1);;
    $ldapc->{ldap_tls} = YaST::YCP::Boolean (0);;
    $ldapc->{login_enabled} = YaST::YCP::Boolean (1);
    $ldapc->{ldap_v2} = YaST::YCP::Boolean (0);
    $ldapc->{start_autofs} = YaST::YCP::Boolean (0);
    $ldapc->{mkhomedir} = YaST::YCP::Boolean (0);
    $ldapc->{sssd} = YaST::YCP::Boolean (0);
    
    Ldap->Import($ldapc);
    Ldap->WriteNow();
    y2milestone("-----End OSS ConfigureLDAPServer----");
}
