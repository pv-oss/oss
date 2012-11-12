#!/usr/bin/perl  -w
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
use strict;
use Net::LDAP;
use Net::LDAP::Entry;

my $entry;

# Get Admin Password
my $ldappw = shift;
if( !$ldappw ) 
{
	$ldappw = `/usr/sbin/oss_get_admin_pw`;
}
else
{
	$ldappw = `cat $ldappw`;
}

# Get ldap base
my $ldapbase = `sed '/#/d' /etc/openldap/ldap.conf | gawk '/base|BASE/ {print \$2}'`;

system("sed -i 's/index serviceAccesControl sub/index role,serviceAccesControl sub/' /etc/openldap/slapd.conf");
# Make LDAP Connection
my $LDAP = Net::LDAP->new('localhost',port =>389 ,version => 3);
$LDAP->bind('cn=Administrator,'.$ldapbase, password=>$ldappw);

open(CONF,"/etc/sysconfig/schoolserver");
my $mesg  = "";
my $type  = "";
my $key   = "";
my $value = "";
my $RO    = "";
my $Path  = "Network/Schoolserver/Basis";
$entry = Net::LDAP::Entry->new;  
$entry->add(objectClass=>'organizationalUnit');
$entry->add(ou=>'sysconfig');
$entry->dn( 'ou=sysconfig,'.$ldapbase );
$mesg = $LDAP->add( $entry );
$entry = Net::LDAP::Entry->new;  
while(<CONF>)
{
  chomp;
  if(/## Path:\s+(.*)/)
  {
    $Path  = $1;
  }
  elsif( /^$/ )
  { # Empty line
     $entry = Net::LDAP::Entry->new;  
     $entry->add(objectClass=>'schoolConfiguration');
  }
  elsif( /^## Type:\s+(\S+)\s+(\w+)/)
  { # Type & RO
     $type = $1;
     if( $type =~ /(\w+)\((\S+)\)/ )
     {
     	$type = $1;
	foreach my $dv (split /,/,$2)
	{ # Default value
	     $entry->add(configurationAvailableValue=>"$dv"); 
	}
     }
     $entry->add(configurationValueType=>"$type"); 
     if( $2 eq 'readonly' )
     {
       $entry->add(configurationValueRO=>'yes'); 
     }
     else
     {
       $entry->add(configurationValueRO=>'no'); 
     }
  }
  elsif( /^## Type:\s+(\S+)/)
  { # Type & RO
     $type = $1;
     if( $type =~ /(\w+)\((\S+)\)/ )
     {
     	$type = $1;
	foreach my $dv (split /,/,$2)
	{ # Default value
	     $entry->add(configurationAvailableValue=>"$dv"); 
	}
     }
     $entry->add(configurationValueType=>"$type"); 
     $entry->add(configurationValueRO=>'no'); 
  }   
  elsif( /^## Default:\s+(\S+)/)
  { # Default value
     $entry->add(configurationDefaultValue=>"$1"); 
  }
  elsif( /^# (.*$)/)
  { # Description
     $entry->add(description=>"$1"); 
  }
  elsif( /^\w+=/)
  { # Key & Value
  	( $key, $value ) = split /=/;
	$value =~ s/^"//;
	$value =~ s/"$//;
	$entry->add(configurationKey=>"$key");
	$entry->add(configurationPath=>"$Path");
	if( $value ne '' )
	{
		$entry->add(configurationValue=>"$value");
	}
	$entry->dn( 'configurationKey='.$key.',ou=sysconfig,'.$ldapbase );
	$mesg = $LDAP->add( $entry );
        $entry = Net::LDAP::Entry->new;  
        $entry->add(objectClass=>'schoolConfiguration');
  }
}
