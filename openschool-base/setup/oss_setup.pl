#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly Nürnberg, Germany.  All rights reserved.
BEGIN{
   push @INC,"/usr/share/oss/lib/";
}
$| = 1; # do not buffer stdout

use strict;
use oss_group;
use oss_user;
use oss_utils;
use ossBaseTranslations;
use Net::Netmask;
use Data::Dumper;
use Getopt::Long;
use Config::IniFiles;
use Time::Local;
use Crypt::SmbHash;
use strict;

# -- Global Variable
my $time = `date  +%Y%m%d%H%M`; chop $time;
# -- ENVIROMENT
my $config	       ='/etc/sysconfig/schoolserver';
my $globals	       = {};

# --Some Object Pointers
my $oss_user  = undef;
my $oss_group = undef;

# --String variables
my $timezone	= 'Europe/Berlin';
my $HOME_BASE	= '/home';
my $ldappasswd	= '';

# --Boolean variables
my $debug	  = 1;
my $is_SUSE    = 1;
my $ALL		= 0;
my $DHCP	= 0;
my $DNS		= 0;
my $LDAP	= 0;
my $SAMBA	= 0;
my $MAIL	= 0;
my $PROXY	= 0;
my $ACCOUNTS	= 0;


# --Network varibales
my $network = '';

# -- Integer variables
my $netcnt	       = 4;
my $i_anon_dhcp_first  = 1;
my $i_anon_dhcp_last   = 254;

# -- List variables
my @lnetmask 	       = ();
my @lbroadcast	       = ();
my @lnetaddr	       = ();
my @localip	       = ();

# -- String variables
my $ossversion = '3.1';

# -- File names
my $cyrusconf  = '/etc/cyrus.conf';
my $imapdconf  = '/etc/imapd.conf';
my $dhcpdconf  = '/etc/dhcpd.conf';
my $dhcp_ldif  = '/var/lib/ldap/dhcp.ldif';
my $dhcp_dns_patch_ldif  = '/var/lib/ldap/dhcp_dns_patch_.ldif';

# -- Network variables
my $internal   = '';
my $netmask    = '';
my $netaddr    = '';
my $broadcast  = '';
my $ldapbase   = '';
my $fqhn       = '';
my $extip      = '';
my $extgw      = '';
my $extnm      = '';
my $hostname   = 'schooladmin';
my $nr_of_room         = '';
my $first_room_net     = '';
my $server_net         = '';
my $anon_dhcp          = '';
my $anon_dhcp_first    = '';
my $anon_dhcp_last     = '';
my $workgroup  = '';
my $passwd     = '';
my $ccode      = 'EN';
my $ldapserver         = 'ldap';
my $ldapbinddn         = '';
my $client_code_page   = '850';
my $character_set      = 'ISO8859-15';
my $netbiosname        = 'PDC-SERVER';
my $serverdescription  = 'Open School Server V'.$ossversion;
my $classes            = '';
my $nclasses           = '5 6 7 8 9 10 11 -12';
my $aclasses           = 'A B C D';
my $schoolservername   = 'schoolserver';
my $aliases_admin      = 'dns samba nfs install timeserver admin ldap schooladmin wpad';
my $aliases_mailserver = 'mailserver mailszerver schoolserver suliszerver schulserver';
my $Lang = 'EN';
my $regcode    = '';

if ( ! -e '/etc/SuSE-release' )
{
    $is_SUSE = 0;
}

##############################
# Helper scripts
##############################
sub AddGroup($$$$$) {
    my $cn	= shift;
    my $disp	= shift;
    my $gid	= shift;
    my $SID	= shift;
    my $type	= shift;

    my $GROUP = {};
    $GROUP->{cn}  = $cn;

    my $desc    = $Translations->{$Lang}->{$cn} || '';
    $GROUP->{grouptype}   = $type;
    if($type eq 'class' )
    {
      $GROUP->{description} = $Translations->{$Lang}->{classname}." $cn";
    }
    elsif($type eq 'primary')
    {
      $GROUP->{role}   = $cn;
    }  
    if($gid != 0)
    {
      $GROUP->{gidnumber}  = $gid;
    }
    if($desc ne '')
    {
      $GROUP->{description}  = $desc;
    }
    if($disp ne '')
    {
      $GROUP->{displayname}  = $disp;
    }
    if($SID ne '')
    {
      $GROUP->{SID}  = $SID;
    }
    $GROUP->{member}  = $ldapbinddn;
    if( ! $oss_group->add($GROUP) )
    {
       print STDERR $oss_group->{ERROR}->{code}."\n";
       print STDERR $oss_group->{ERROR}->{text}."\n";
    }
   print DEBUG "###########\n#AddGroup\n###########\n".Dumper($GROUP)."\n##############\n" if ($debug);

}

sub AddUser($$$) {
    my $uid       = shift;
    my $uidnumber = shift;
    my $role      = shift;
    my $USER	  = {};
    my $passwd    = get_file($ldappasswd);
    chomp $passwd;

    $USER->{uid}  		= $uid;
    $USER->{sn}  		= $Translations->{$Lang}->{$uid} || $Translations->{EN}->{$uid};
    $USER->{c}	  		= $ccode;
    $USER->{quota}	  	= 0;
    $USER->{fquota}	  	= 0;
    $USER->{preferredlanguage}	= $Lang;
    $USER->{o}			= $globals->{NAME};
    $USER->{uidnumber}		= $uidnumber;
    $USER->{role}		= $role;
    $USER->{userpassword}	= $passwd;
    $USER->{oxtimezone}		= $timezone;
    $USER->{maildomain}		= $globals->{DOMAIN};

    if( ! $oss_user->add($USER) )
    {
       print STDERR $oss_user->{ERROR}->{code}."\n";
       print STDERR $oss_user->{ERROR}->{text}."\n";
    }

   print DEBUG "###########\n#AddUser\n###########\n".Dumper($USER)."\n##############\n" if ($debug);

}

sub revip {
  my $IP = shift;
  my @ip = split /\./,$IP;
  my $i = 0; 
  my @tmp = ();
  while( $i < $netcnt ) {
        push @tmp, $ip[4 - $i - 1];
        $i = $i + 1;
  }
  return join '.',@tmp;
}

sub writef {
  my $file = shift;
  my $cont = shift;
  open(F,">$file");
  print F $cont;
  close(F);
}

##############################################
# Main Subroutines
#############################################

sub PreSetup
{

   print STDERR "Executing PreSetup ...\n";
   my @tmp  = ();
   my ( $key, $value );

   open IN,$config;
   while (<IN>) {
	next if (/^#/);
	/SCHOOL_(.*)="(.*)"/;
	if(defined $1)
	{
	    $key   = $1;
	    $value = $2;
	    $globals->{$key} = $value;
	    print STDERR $key.'=>'.$globals->{$key}.":\n" if ($debug);
	}
   }
   close(IN);
   if( defined $globals->{HOME_BASE} )
   {
     $HOME_BASE = $globals->{HOME_BASE};
   }

   # If no ldapbase defined we set it
   if( !$globals->{LDAPBASE} )
   {
	print STDERR "We generate the LDAPBASE";
	my @domain = split /\./, $globals->{DOMAIN};
	foreach (@domain)
	{
	   $ldapbase .= "dc=".$_.",";
	}
	$ldapbase =~ s/,$//;
	$globals->{LDAPBASE} = $ldapbase;
   }
   else
   {
	$ldapbase=$globals->{LDAPBASE};
   }
   # Seting the hostname
   system("hostname schooladmin; echo 'schooladmin.".$globals->{DOMAIN}."' > /etc/HOSTNAME;");
   $ldapbase =~ /dc=(.*?),/;
   $globals->{TOPDOMAIN} = $1;
   $ldapbinddn = 'cn=Administrator,'.$ldapbase;

   # If no workgroup defined we set it
   if( !$globals->{WORKGROUP} )
   {
	print STDERR "We generate the WORKGROUP";
	my @tmp = split /\./, $globals->{WORKGROUP};
	$workgroup = $tmp[$#tmp-2];
   }
   else
   {
	$workgroup=$globals->{WORKGROUP};
   }
   if( length($workgroup) > 14 )
   {
       print STDERR "The name of the workgroup '$workgroup' is to long, we've trunkated it to 14 chars.";
       $workgroup = substr $workgroup,0,14;
   }

   # If netbios name is defined we use it
   if( $globals->{NETBIOSNAME} )
   {
      $netbiosname = $globals->{NETBIOSNAME};
   }
   $netbiosname = lc($netbiosname);

   # If language defined we use it
   if( $globals->{LANGUAGE} )
   {
      $Lang = $globals->{LANGUAGE};
   }

   # If country defined we use it
   if( $globals->{CCODE} )
   {
      $ccode = $globals->{CCODE};
   }

   # If we have a classless network...
   # modify netmask to match into the next greater CLASS
   @lnetmask = split /\./, $globals->{NETMASK};
   my $i    = 0;
   while( $i < 4 )
   {
            if( $lnetmask[$i] < 255 )
	    {
                push @tmp, "0";
            }
	    else
	    {
                push @tmp, "255";
                $netcnt--;
            }
            $i = $i + 1;
   }
   if( $globals->{USE_DHCP} ne 'no' )
   {
	   @lnetmask = @tmp;
	   ($anon_dhcp_first, $anon_dhcp_last) = split / /, $globals->{ANON_DHCP_RANGE};
	   @tmp = split /\./, $anon_dhcp_first;
	   $i_anon_dhcp_first = $tmp[3];
	   @tmp = split /\./, $anon_dhcp_last;
	   $i_anon_dhcp_last = $tmp[3];
   }

   # Calculte Network Address
   my $block = new Net::Netmask($globals->{SERVER}.'/'.$globals->{NETMASK});
   $network  = $block->base();
   $globals->{BNETMASK} = $block->bits();

   print STDERR "NETCNT: $netcnt\n" if($debug);

   #Findout Classes
   if( $globals->{CLASSES} )
   {
      $classes = $globals->{CLASSES};
   }
   else
   {
	if( $globals->{NCLASSES} )
	{
		$nclasses = $globals->{NCLASSES};
	}
	if( $globals->{ACLASSES} )
	{
		$aclasses = $globals->{ACLASSES};
	}
	$classes = "";
	my @nl = split / /, $nclasses;
	if ( ! $#nl  )
	{
	  @nl = ( "*" );
	}
	foreach my $n ( @nl )
	{
	  my @al = ();
	  if ( $n eq " " || $n eq "" )
	  {
	     next;
	  }
	  if ( $n eq "*" )
	  {
	     $n = "";
	  }
	  if( substr($n,0,1) eq "-" )
	  {
	    @al = ( "*" );
	    $n = substr($n,1,10);
	    next if ( $n eq " " || $n eq "" );
	  }
	  else
	  {
	    @al = split / /, $aclasses;
	  }
	  foreach my $a ( @al ) {
	    next if ( $a eq " " || $a eq "" );
	    if ( $a eq "*" )
	    {
	      $a = "";
	    }
	    if( $classes ne "" )
	    {
	      $classes .= " " . $n . $a;
	    }
	    else
	    {
	      $classes .= $n . $a;
	    }
	  }
	}
   }
   # If we already have made PreSetup we do not need to do
   # the next steps
   if( -e  "/var/adm/oss/PreSetupDone" )
   {
      print STDERR "PreSetup allready done ...\n";
      sleep 2;
      return;
   }

   print STDERR "Evaluating Timezone ...";
   if( -e "/etc/sysconfig/clock" )
   {
      $timezone = `. /etc/sysconfig/clock; echo \$TIMEZONE`;
      chomp $timezone;
   }
   print STDERR "$timezone \n";

   print STDERR "Setting up the Timeserver ...\n";
   system("oss_copy_backup.sh /etc/ntp.conf in; rcntp start; chkconfig ntp on;");

   print STDERR "Creating ssh keys ...\n";
   system("cd /root
/bin/mkdir .ssh
/usr/bin/ssh-keygen -t dsa -N '' -f .ssh/id_dsa
cp /root/.ssh/id_dsa.pub /root/.ssh/authorized_keys
/bin/chmod 600 /root/.ssh/authorized_keys
echo 'stricthostkeychecking no' > /root/.ssh/config
");
   # Write /etc/hosts
   $aliases_admin = $aliases_admin." ".$netbiosname;
   my $etc_hosts = "#
# hosts         This file describes a number of hostname-to-address
#               mappings for the TCP/IP subsystem.  It is mostly
#               used at boot time, when no name servers are running.
#               On small systems, this file can be used instead of a
#               \"named\" name server.
# Syntax:
#    
# IP-Address  Full-Qualified-Hostname  Short-Hostname
#

127.0.0.1       localhost

# special IPv6 addresses
# this must be comment out becouse of openXchange
#::1             localhost ipv6-localhost ipv6-loopback

fe00::0         ipv6-localnet

ff00::0         ipv6-mcastprefix
ff02::1         ipv6-allnodes
ff02::2         ipv6-allrouters
ff02::3         ipv6-allhosts
".$globals->{SERVER}.     "     schooladmin.".$globals->{DOMAIN}." admin.".$globals->{DOMAIN}." admin ".$aliases_admin."
".$globals->{MAILSERVER}. "     mailserver.".$globals->{DOMAIN}." mailserver ".$aliases_mailserver."
".$globals->{PRINTSERVER}."     printserver.".$globals->{DOMAIN}." printserver
".$globals->{PROXY}.      "     proxy.".$globals->{DOMAIN}." proxy
".$globals->{BACKUP_SERVER}."     backup.".$globals->{DOMAIN}." backup
";

   writef("/etc/hosts",$etc_hosts);

   my $todo = "sed -i 's#SCHOOL_SERVER_NET#".$globals->{SERVER_NET}."#' /etc/snmpd.conf.in > /etc/snmpd.conf;" .
              "mkdir -p /var/adm/oss; touch /var/adm/oss/PreSetupDone ;";

   if(! -e "/home/aquota.user" ){
   	$todo .= "quotacheck -f /home;";
   }

   print DEBUG "###########\n#PRE SETUP\n###########\n$todo\n##############\n" if ($debug);
   print DEBUG "CLASSEN: $classes\n" if($debug);
   system($todo);
}

sub SetupLDAP
{
   print STDERR "Setting up LDAP-Server for ldapsuffix: $ldapbase\n";

   my $passwd    = get_file($ldappasswd);
   chomp $passwd;
   my $crypt = hash_password( 'smd5' , $passwd);
   my $baseldif = '/var/lib/ldap/LDAP_BASE.ldif';
   my $todo     = "cp /usr/share/oss/setup/ldap/* /var/lib/ldap/\n";

   # For SUSE the LDAP server hase allready set up and we use the SUSE tools
   # We only need to setup the acls
   if( $is_SUSE ) 
   {
        $todo .= "/usr/sbin/oss_sysconfig_to_ldap.pl $ldappasswd;
sed -i 's/#LDAPBASE#/$ldapbase/g' /var/lib/ldap/acls.ldif
ldapmodify -c -Y external -H ldapi:/// < /var/lib/ldap/acls.ldif
";
   $todo .= 'echo "dn: olcOverlay=memberof,olcDatabase={1}hdb,cn=config
objectClass: olcOverlayConfig
olcOverlay: memberof" | ldapadd -Y external -H ldapi:/// 
';
   }
   else
   {
   	$todo .= "sed -i 's/#LDAPBASE#/$ldapbase/' /etc/openldap/slapd.conf.in
sed -i 's#CRYPTEDPW#$crypt#' /etc/openldap/slapd.conf.in
sed -i 's/#NETWORK#/".$globals->{NETWORK}."/' /etc/openldap/slapd.conf.in
sed -i 's/#NETMASK#/".$globals->{NETMASK}."/' /etc/openldap/slapd.conf.in
oss_copy_backup.sh /etc/openldap/slapd.conf in; 
sed -i 's/#LDAPBASE#/$ldapbase/' /etc/openldap/ldap.conf.in
oss_copy_backup.sh /etc/openldap/ldap.conf in; 
sed -i 's/#LDAPBASE#/$ldapbase/' /etc/ldap.conf.in
oss_copy_backup.sh /etc/ldap.conf in; 
for i  in /etc/openldap/schema/*in
do
   schema=`basename \$i .in`
   cp \$i /etc/openldap/schema/\$schema
done
sed -i 's/#ORGANISATION#/".$globals->{NAME}."/' $baseldif; 
sed -i 's/#TOPDOMAIN#/".$globals->{TOPDOMAIN}."/' $baseldif; 
sed -i 's/#LDAPBASE#/$ldapbase/' $baseldif; 
sed -i 's/#DOMAIN#/$globals->{DOMAIN}/' $baseldif; 
sed -i 's/#WORKGROUP#/$workgroup/' $baseldif; 
rcldap	restart
";
   # Add base entries;
   $todo .= "echo Add base ldap entries ...
	      /usr/bin/ldapadd -x -c -a ".
              " -D '" .$ldapbinddn.
              "' -y '" .$ldappasswd.
              "' -f  /var/lib/ldap/LDAP_BASE.ldif\n";
   }

   $todo .= "/usr/sbin/oss_sysconfig_to_ldap.pl '$ldappasswd'\n";

   print DEBUG "###########\n#LDAP SERVER SETUP\n###########\n$todo\n##############\n" if ($debug);
   system($todo);
}

sub SetupDNS
{
   print STDERR "Setting up DNS-Server for domain: $globals->{DOMAIN}\n";
   my $baseldif = '/var/lib/ldap/LDAP_DNS.ldif';
   my $dhcpldif = '';

   #Calculate the reverse lookups
   my @tmp      = ();
   my $i        = 4 - $netcnt;
   my @ip       = split /\./,$globals->{SERVER};
   while( $i > 0 )
   {
        push @tmp, $ip[$i - 1];
        $i = $i - 1;
   }
   my $REVZONE = join '.',@tmp;
   my $REVIPADDRESS  = revip($globals->{SERVER});
   my $REVMAILSERVER = revip($globals->{MAILSERVER});
   my $REVPRINTSERVER= revip($globals->{PRINTSERVER});
   my $REVPROXY      = revip($globals->{PROXY});
   my $REVBACKUP     = revip($globals->{BACKUP_SERVER});


   if( $globals->{USE_DHCP} ne 'no' )
   {
	$i = 2; @tmp = ();
	my @lanon_dhcp_first = split /\./, $anon_dhcp_first;
	while( $i > 3 - $netcnt )
	{ 
	        push @tmp, $lanon_dhcp_first[$i];
	        $i = $i - 1;
	}
	my $anon_dhcp_revnet = join '.',@tmp;
	
	$i = 0; @tmp = ();
	while( $i < 3 )
	{
	        push @tmp, $lanon_dhcp_first[$i];
	        $i = $i + 1;
	}
	my $anon_dhcp_net = join '.',@tmp;
	
	my $PoolDN = "cn=Pool1,cn=$network,cn=config1,cn=$hostname,ou=DHCP,$ldapbase";
	$i = $i_anon_dhcp_first;
	while( $i < $i_anon_dhcp_last + 1 )
	{
	    $dhcpldif .= "
dn: relativeDomainName=dhcp$i,zoneName=$globals->{DOMAIN},ou=DNS,$ldapbase
aRecord: $anon_dhcp_net.$i
objectClass: dNSZone
objectClass: DHCPEntry
dNSClass: IN
dNSTTL: 604800
relativeDomainName: dhcp$i
zoneName: $globals->{DOMAIN}
dhcpPoolDN: $PoolDN

dn: relativeDomainName=$i,zoneName=$REVZONE.IN-ADDR.ARPA,ou=DNS,$ldapbase
objectClass: dNSZone
objectClass: DHCPEntry
dNSClass: IN
dNSTTL: 604800
pTRRecord: dhcp$i.$globals->{DOMAIN}.
relativeDomainName: $i
zoneName: $REVZONE.IN-ADDR.ARPA
dhcpPoolDN: $PoolDN
";
	    $i = $i + 1;
	}
	open OUT, ">>$baseldif";
	print OUT $dhcpldif;
	close(OUT);
   } # END $globals->{ANON_DHCP}

   my $todo = "sed -i 's/#LDAPBASE#/$ldapbase/g' $baseldif; 
sed -i 's/#NETBIOSNAME#/$netbiosname/g' $baseldif; 
sed -i 's/#DOMAIN#/$globals->{DOMAIN}/g' $baseldif; 
sed -i 's/#IPADDRESS#/$globals->{SERVER}/g' $baseldif; 
sed -i 's/#MAILSERVER#/$globals->{MAILSERVER}/g' $baseldif; 
sed -i 's/#PRINTSERVER#/$globals->{PRINTSERVER}/g' $baseldif; 
sed -i 's/#PROXY#/$globals->{PROXY}/g' $baseldif; 
sed -i 's/#BACKUP#/$globals->{BACKUP_SERVER}/g' $baseldif; 
sed -i 's/#REVZONE#/$REVZONE/g' $baseldif; 
sed -i 's/#REVIPADDRESS#/$REVIPADDRESS/g' $baseldif; 
sed -i 's/#REVMAILSERVER#/$REVMAILSERVER/g' $baseldif; 
sed -i 's/#REVPRINTSERVER#/$REVPRINTSERVER/g' $baseldif; 
sed -i 's/#REVPROXY#/$REVPROXY/g' $baseldif; 
sed -i 's/#REVBACKUP#/$REVBACKUP/g' $baseldif; 
sed -i 's/#WORKGROUP#/$workgroup/g' $baseldif;
sed -i 's/NAMED_INITIALIZE_SCRIPTS=.*/NAMED_INITIALIZE_SCRIPTS=\"createNamedConfInclude ldapdump\"/' /etc/sysconfig/named
";
   # Adding DNS LDAP entries;
   $todo .= "echo Add DNS ldap entries ...
	      /usr/bin/ldapadd -x -c -a ".
              " -D '".$ldapbinddn.
              "' -y '".$ldappasswd.
              "' -f  /var/lib/ldap/LDAP_DNS.ldif\n";

   system($todo);
   print DEBUG "###########\n#DNS SERVER SETUP\n###########\n$todo\n##############\n" if ($debug);
}

sub SetupDHCP
{
   print STDERR "Setting up DHCP-server for the network: $network\n";
   my $block = new Net::Netmask($globals->{SERVER_NET});
   my $server_nm = $block->bits();
   $server_net = $block->base();

   if( $globals->{USE_DHCP} ne 'no' ) 
   {
      $block = new Net::Netmask($anon_dhcp_first.'/'.$server_nm);
      $anon_dhcp_first = $block->base();
   }

   my $baseldif = '/var/lib/ldap/LDAP_DHCP.ldif';
   my $dhcpldif = "dn: ou=DHCP,$ldapbase
objectClass: top
objectClass: organizationalUnit
ou: DHCP

dn: cn=$hostname,ou=DHCP,$ldapbase
cn: $hostname
dhcpServiceDN: cn=config1,cn=$hostname,ou=DHCP,$ldapbase
objectClass: top
objectClass: dhcpServer
objectClass: dhcpOptions

dn: cn=config1,cn=$hostname,ou=DHCP,$ldapbase
cn: config1
dhcpOption: domain-name \"$globals->{DOMAIN}\"
dhcpOption: domain-name-servers $globals->{SERVER}
";
if( $globals->{NET_GATEWAY} )
{
	$dhcpldif .="dhcpOption: routers $globals->{NET_GATEWAY}\n";
}
$dhcpldif .="dhcpOption: time-servers $globals->{SERVER}
dhcpOption: lpr-servers $globals->{PRINTSERVER}
dhcpOption: netbios-name-servers $globals->{SERVER}
dhcpOption: wpad-curl code 252 = text
dhcpOption: wpad-curl \"http://admin.$globals->{DOMAIN}/proxy.pac\"
dhcpPrimaryDN: cn=$hostname,ou=DHCP,$ldapbase
dhcpStatements: ddns-update-style none
dhcpStatements: default-lease-time 86400
dhcpStatements: max-lease-time 172800
dhcpStatements: authoritative
dhcpStatements: use-host-decl-names true
objectClass: dhcpService
objectClass: dhcpOptions
objectClass: top

dn: cn=$network,cn=config1,cn=$hostname,ou=DHCP,$ldapbase
cn: $network
dhcpNetMask: $globals->{BNETMASK}
dhcpStatements: filename \"pxelinux.0\"
dhcpStatements: next-server $globals->{SERVER}
objectClass: dhcpSubnet
objectClass: dhcpOptions
objectClass: top

";

if( $globals->{USE_DHCP} ne 'no' ) 
{
$dhcpldif .="dn: cn=Pool1,cn=$network,cn=config1,cn=$hostname,ou=DHCP,$ldapbase
cn: Pool1
dhcpRange: dynamic-bootp $globals->{ANON_DHCP_RANGE}
objectClass: dhcpPool
objectClass: dhcpOptions
objectClass: top
dhcpStatements: allow unknown clients
dhcpStatements: deny  known clients
dhcpStatements: default-lease-time 300
dhcpStatements: max-lease-time 600

";
}

$dhcpldif .="dn: cn=Room-2,cn=$network,cn=config1,cn=$hostname,ou=DHCP,$ldapbase
objectClass: top
objectClass: dhcpOptions
objectClass: dhcpGroup
objectClass: SchoolRoom
cn: Room-2
description: SERVER_NET
dhcpNetMask: $server_nm
dhcpRange: $server_net

dn: cn=Room-1,cn=$network,cn=config1,cn=$hostname,ou=DHCP,$ldapbase
objectClass: top
objectClass: dhcpOptions
objectClass: dhcpGroup
objectClass: SchoolRoom
cn: Room-1
description: ANON_DHCP
dhcpNetMask: $server_nm
dhcpRange: $anon_dhcp_first
serviceAccesControl: 06:00 DEFAULT
";


  if( $globals->{TYPE} eq 'primary' )
  {
    $dhcpldif .= "serviceAccesControl: DEFAULT all:0 internet:1 printing:1 mailing:1 samba:1\n";
  }
  else
  {
    $dhcpldif .= "serviceAccesControl: DEFAULT all:0 internet:0 printing:0 mailing:0 samba:0\n";
  }

  my $i = 0;
  my ($a, $b, $c, $d) = split /\./,$globals->{FIRST_ROOM_NET};
  $d=0 if( $d != 0 && $d != 64 && $d != 128 && $d != 172 );
  while( $i < $globals->{ROOM_NR})
  {
    my $roomnet = "$a.$b.$c.$d";
    $dhcpldif .= "
dn: cn=Room$i,cn=$network,cn=config1,cn=$hostname,ou=DHCP,$ldapbase
objectClass: top
objectClass: dhcpOptions
objectClass: dhcpGroup
objectClass: SchoolRoom
cn: Room$i
dhcpNetMask: 26
dhcpRange: $roomnet
";
      $d = $d + 64;
      if( $d > 255)
      {
         $d = 0;
         $c = $c + 1;
         if( $c > 255 )
	 {
            $c = 0;
            $b = $b + 1;
         }
      }
      $i = $i+1;
  }
  open OUT, ">$baseldif";
  print OUT $dhcpldif;
  close(OUT);
  # Adding DHCP entries;
  my $todo = "echo Add DHCP ldap entries ...
	      /usr/bin/ldapadd -x -c -a ".
              " -D '".$ldapbinddn.
              "' -y '".$ldappasswd.
              "' -f  /var/lib/ldap/LDAP_DHCP.ldif \n";

   # Write dhcp configuration file & adjust service dhcpd
   $todo .= "sed -i 's/#LDAPBASE#/$ldapbase/g' /etc/dhcpd.conf.in
oss_copy_backup.sh /etc/dhcpd.conf in
rcdhcpd start; chkconfig dhcpd on;\n";
   system($todo);
   print DEBUG "###########\n#DNS SERVER SETUP\n###########\n$todo\n##############\n" if ($debug);

}

sub SetupMail
{
   print STDERR "Setting up Mail-server for the domain: $globals->{DOMAIN}\n";

   my $todo = "for i in /etc/postfix/*
do 
   sed -i 's/#LDAPBASE#/$ldapbase/g' \$i; 
done
for i in /etc/postfix/*
do 
  sed -i 's/#DOMAIN#/$globals->{DOMAIN}/g' \$i; 
done
echo \"$globals->{DOMAIN} OK\" > /etc/postfix/local_domains
for i in /etc/postfix/*.in
do
   name=`basename \$i .in`
   cp \$i /etc/postfix/\$name
done
postmap /etc/postfix/local_domains
cat $ldappasswd | passwd --stdin cyrus
oss_copy_backup.sh /etc/imapd.conf in
oss_copy_backup.sh /etc/cyrus.conf in
sed -i 's/#DOMAIN#/$globals->{DOMAIN}/g' /etc/postfix/main.cf.in; 
oss_copy_backup.sh /etc/postfix/main.cf in
oss_copy_backup.sh /etc/postfix/master.cf in
oss_copy_backup.sh /etc/imap/procmailrc in
chkconfig saslauthd on
chkconfig postfix on
chkconfig cyrus on
chkconfig freshclam on
rcsaslauthd start
rcpostfix   start
rccyrus     start
echo -n 'Waiting for cyrus come up '
for i in 0 1 2 3 4 5 6 7 8 9; do   sleep 1;   echo -n '.'; done
sed 's/#LDAPBASE#/$ldapbase/g' /usr/share/oss/setup/ldap/LDAP_EXTIS_MAILTRANSPORT.ldif > /var/lib/ldap/LDAP_EXTIS_MAILTRANSPORT.ldif
sed 's/#LDAPBASE#/$ldapbase/g' /usr/share/oss/setup/ldap/LDAP_AUTOFS.ldif              > /var/lib/ldap/LDAP_AUTOFS.ldif
/usr/bin/ldapadd -x -c -a  -D '$ldapbinddn' -y '$ldappasswd' -f  /var/lib/ldap/LDAP_EXTIS_MAILTRANSPORT.ldif
/usr/bin/ldapadd -x -c -a  -D '$ldapbinddn' -y '$ldappasswd' -f  /var/lib/ldap/LDAP_AUTOFS.ldif
echo";

   system($todo);
   print DEBUG "###########\n#MAIL SERVER SETUP\n###########\n$todo\n##############\n" if ($debug);
}

sub SetupSAMBA
{
   print STDERR "Setting up SAMBA-server for the workgroup/domain: $workgroup\n";

   my $smbconf = "/etc/samba/smb.conf.in";
   if( $globals->{TYPE} eq 'primary' )
   {
      $smbconf = "/etc/samba/smb.primaryschool.in";
   }

   my $todo = "if [ -e /var/lib/samba/netlogon/netlogon_$Lang.tgz ]
then
  cd /var/lib/samba/netlogon/
  tar xzf netlogon_$Lang.tgz
fi
mkdir -p /var/lib/samba/netlogon/{UNKNOWN,Vista,Win2K,Win2K3,Win95,Win98,WinNT,WinXP}
for i in  /var/lib/samba/netlogon/*in
do
  perl  -pi -e s/#PDC-SERVER#/$netbiosname/ \$i
  a=`basename \$i .in`
  oss_copy_backup.sh /var/lib/samba/netlogon/\$a in
  for j in UNKNOWN Vista Win2K Win2K3 WinNT WinXP
  do
    test -e /var/lib/samba/netlogon/\$j/\$a || ln -s /var/lib/samba/netlogon/\$a /var/lib/samba/netlogon/\$j/\$a
  done
done
for i in  /etc/samba/*.in
do
  sed -i s/#PDC-SERVER#/$netbiosname/g \$i
  sed -i s/#IPADDR#/$globals->{SERVER}/g \$i
  sed -i s/#BINDDN#/$ldapbinddn/g \$i
  sed -i s/#LDAPBASE#/$ldapbase/g \$i
  sed -i s/#WORKGROUP#/$workgroup/g \$i
  sed -i s/#PRINTSERVER#/$globals->{PRINTSERVER}/g \$i
done
cp $smbconf /etc/samba/smb.conf
cp /etc/samba/printserver.conf.in /etc/samba/printserver.conf
mkdir -p /var/run/samba/printserver /var/lib/samba/printserver /etc/samba/printserver
smbpasswd -w \$( cat $ldappasswd )
chkconfig nmb on
chkconfig smb on
chkconfig smb-printserver on
chkconfig nmb-printserver on
i=0
until [ \"\$SDN\" ];
do
    sleep 3;
    /etc/init.d/nmb restart
    /etc/init.d/smb restart
    /etc/init.d/nmb-printserver restart
    /etc/init.d/smb-printserver restart
    sleep 1;
    SDN=\$(oss_ldapsearch sambadomainname=*)
    [ \$i -gt 0 ] && echo \"Creating samba domain try \$i\"
    [ \$i -gt 9 ]  && break
    i=\$((i+1))
done
net SAM POLICY SET 'maximum password age' 86313600
";

   print DEBUG "###########\n#SAMBA SERVER SETUP\n###########\n$todo\n##############\n" if ($debug);

   system($todo);
}

sub SetupInitialAccounts
{
   print STDERR "--- SetupInitialAccounts ---\n";
my $my_pictures  = $Translations->{$Lang}->{my_pictures} || $Translations->{EN}->{my_pictures};
my $my_music     = $Translations->{$Lang}->{my_music} || $Translations->{EN}->{my_music};
my $todo = ". /etc/sysconfig/schoolserver
/bin/mkdir -p /etc/skel/Import
/bin/mkdir -p /etc/skel/Export
/bin/mkdir -p /etc/skel/public_html
/bin/mkdir -p '/etc/skel/$my_pictures'
/bin/mkdir -p '/etc/skel/$my_music' 
if [ -e /etc/xdg/menus/gnome-applications.menu ]
then
  mkdir -p /etc/skel/.config/menus/
  cp /etc/xdg/menus/gnome-applications.menu /etc/skel/.config/menus/applications.menu
  cp -a /etc/skel/.config /root
fi
/bin/mkdir -m 755 -p $HOME_BASE/archiv
/bin/mkdir -m 755 -p $HOME_BASE/groups
/bin/mkdir -m 755 -p $HOME_BASE/profile
/bin/mkdir -m 770 -p $HOME_BASE/all
/bin/mkdir -m 755 -p /mnt/backup
if [ \$SCHOOL_TYPE = 'primary' ]
then
        /bin/chmod    1777   $HOME_BASE/all
else
        /bin/chmod    1770   $HOME_BASE/all
fi
/bin/mkdir -m 775 -p $HOME_BASE/software
/bin/chmod    1775   $HOME_BASE/software
/bin/cp -a /etc/skel/Desktop /root
if [ ".$globals->{TEACHER_OBSERV_HOME}." = 'yes' ]
then
   /bin/mkdir -m 750 -p $HOME_BASE/classes
fi
";

   system($todo);
   print DEBUG "###########\n#Setup Initial Accounts\n###########\n$todo\n##############\n" if ($debug);

        AddGroup("sysadmins","Domain Admins",500,512,"primary");
        AddGroup("domainusers","Domain Users",999,513,"helper");
        AddGroup("students","",501,0,"primary");
        AddGroup("teachers","",502,0,"primary");
        AddGroup("workstations","",503,0,"primary");
        AddGroup("administration","",504,0,"primary");
        AddGroup("guests","Domain Guests",505,514,"helper");
        AddGroup("templates","Domain Template Users",506,0,"primary");
        AddUser("admin",1999,"sysadmins");
        AddUser("tstudents",1998,"students,templates");
        AddUser("tteachers",1997,"teachers,templates");
        AddUser("tadministration",1996,"administration,templates");
        AddUser("tworkstations",1995,"workstations,templates");

$todo = ". /etc/sysconfig/schoolserver
echo 'dn: cn=SYSADMINS,ou=group,$ldapbase
add: member
member: uid=Administrator,ou=people,$ldapbase
' | oss_ldapmodify
echo 'dn: cn=DOMAINUSERS,ou=group,$ldapbase
add: member
member: uid=Administrator,ou=people,$ldapbase
' | oss_ldapmodify
/bin/chgrp templates $HOME_BASE/templates
/usr/bin/setfacl -m m::rwx               $HOME_BASE/all
/usr/bin/setfacl -m g:teachers:rwx       $HOME_BASE/all
/usr/bin/setfacl -m g:students:rwx       $HOME_BASE/all
/usr/bin/setfacl -m g:administration:rwx $HOME_BASE/all
/usr/bin/setfacl -m g:sysadmins:rwx      $HOME_BASE/all
/bin/chgrp teachers                      $HOME_BASE/software
/usr/bin/setfacl -m g:students:rx        $HOME_BASE/software
/usr/bin/setfacl -m g:administration:rx  $HOME_BASE/software
/usr/bin/setfacl -m g:sysadmins:rwx      $HOME_BASE/software
/bin/chgrp          students             $HOME_BASE/students
/bin/chgrp          teachers             $HOME_BASE/teachers
/bin/chgrp          administration       $HOME_BASE/administration
/bin/chgrp          workstations         $HOME_BASE/workstations
/usr/bin/setfacl -m g:teachers:rx        $HOME_BASE/workstations
/usr/bin/setfacl -m g:teachers:rx       $HOME_BASE/groups/STUDENTS
/usr/bin/setfacl -d -m g:teachers:rx    $HOME_BASE/groups/STUDENTS
/bin/rm -rf $HOME_BASE/groups/{WORKSTATIONS,DOMAINUSERS,GUESTS,STUDENTS,TEMPLATES}
/usr/sbin/setquota admin 0 0 0 0 -a
if [ \$SCHOOL_TEACHER_OBSERV_HOME = 'yes' ]
then
   /bin/chgrp teachers $HOME_BASE/classes
   /usr/bin/setfacl -d -m g:teachers:rx $HOME_BASE/students
   echo '[classes]
   browseable = yes
   comment = Folder to Observ the Students Home Directories
   valid users = \@teachers
   guest ok = no
   path = /home/classes
   writable = yes
   wide links = yes
' >> /etc/samba/$netbiosname.in
   sed -i 's/^REM (.*classes)/\$1/' /var/lib/samba/netlogon/teachers.bat
fi
mkdir -p /srv/itool/{config,hwinfo,images,ROOT}
chmod 755  /srv/itool
chgrp -R sysadmins /srv/itool
chmod 4770 /srv/itool/{config,hwinfo,images}
chmod 755  /srv/itool/ROOT
setfacl -m    g::rwx /srv/itool/images
setfacl -d -m g::rwx /srv/itool/images
setfacl -m    g:teachers:rx /srv/itool/{config,images}
setfacl -d -m g:teachers:rx /srv/itool/{config,images}
setfacl -m    g:workstations:rx /srv/itool/{config,images}
setfacl -d -m g:workstations:rx /srv/itool/{config,images}
";
        # create new /etc/exports file
        my $nfs_exports = "# see the exports(5) manpage for a description of the syntax of this file.
# this file contains a list of all directories that are to be exported to 
# other computers via nfs (network file system).
# this file used by rpc.nfsd and rpc.mountd. see their manpages for details
# on how make changes in this file effective.
#
# this file was adapted special for the Open  School Server
#
# péter varkoly <peter\@varkoly.de>
#
$HOME_BASE *." . $globals->{DOMAIN} . "(rw,async,no_subtree_check)
# please uncomment this line if you want to install SUSE LINUX clients via nfs
# don't forget to make \"rcnfsserver reload\" to take the changes in effect
#/srv/ftp        *(ro,async,no_subtree_check)
# please uncomment this line if you mount the suse linux dvd into /srv/ftp/akt/CD1
# don't forget to make \"rcnfsserver reload\" to take the changes in effect
#/srv/ftp/akt/CD1   *(ro,async,no_subtree_check)
";

   open OUT,">/etc/exports";
   print OUT $nfs_exports;
   close(OUT);   
#   $todo .= "chkconfig portmap on\n";
#   $todo .= "chkconfig nfslock on\n";
   $todo .= "chkconfig nfsserver on\n";
   $todo .= "chkconfig quotad on\n";

    # Configure quota
#   my $warnquota =  "LDAP_MAIL = true
#LDAP_HOST = ".$ldapserver."
#LDAP_PORT = 389
#LDAP_BASEDN = ou=people,".$ldapbase."
#LDAP_SEARCH_ATTRIBUTE = uid
#LDAP_MAIL_ATTRIBUTE = suseMailAcceptAddress
#LDAP_DEFAULT_MAIL_DOMAIN = ".$globals->{DOMAIN}."
#\n";
#   open OUT,">/etc/warnquota.conf";
#   print OUT $warnquota;
#   close(OUT);   

   $todo .= "gawk '{if( /home/ ) print $1 \": Linux Open School Server\"}' /etc/fstab > /etc/quotatab\n";

   system($todo);
   print DEBUG "###########\n#SETUP INITIAL ACCOUNTS\n###########\n$todo\n##############\n" if ($debug);

   # create group directories for the classes
   my $i = 1000;
   foreach my $class (split / /, $classes)
   {
        AddGroup($class,"",$i,0,"class");
        $i++;
   }

}


sub SetupGroupware
{
   print STDERR "------ Setting up Groupware Server ------\n";
  
   my $todo = 'oss_copy_backup.sh /etc/apache2/listen.conf in
              oss_copy_backup.sh /etc/apache2/mod_perl-startup.pl in
';

      my $ldif = "dn: ou=ResourceObjects,".$ldapbase."
objectclass: top
objectclass: organizationalUnit
ou: ResourceObjects

dn: resourceGroupName=Rooms,ou=ResourceObjects,".$ldapbase."
objectclass: OXResourceGroupObject
resourceGroupName: Rooms
resourceGroupAvailable: TRUE
resourceGroupDescription: ".$Translations->{$Lang}->{rooms} || 'Rooms'."

";

      open OUT,">/tmp/ResourceObjects.ldif";
      print OUT $ldif;
      close(OUT);   
      $todo .= "/usr/bin/ldapadd -x -c -a ".
                " -D '".$ldapbinddn.
                "' -y '".$ldappasswd.
                "' -f /tmp/ResourceObjects.ldif".
                " 2>&1 > /dev/null\n";

   system($todo);
   print DEBUG "###########\n#GROUPWARE SERVER SETUP\n###########\n$todo\n##############\n" if ($debug);

}

sub SetupProxy
{

  print STDERR "------ Setting up Proxy Server ------\n";
  my $todo = "mv /etc/squid/squid.conf      /etc/squid/squid.conf.orig
  sed 's/#DOMAIN#/".$globals->{DOMAIN}."/g'            /srv/www/admin/proxy.pac.in > /srv/www/admin/proxy.pac
  sed -i 's/#DOMAIN#/".$globals->{DOMAIN}."/g'         /srv/www/cgi-bin/oss-stop.cgi
  sed -i 's/#LDAPSERVER#/".$globals->{SERVER}."/g'     /etc/squid/squid.conf.in
  sed -i 's/#LDAPBASE#/".$globals->{LDAPBASE}."/g'     /etc/squid/squid.conf.in
  sed -i 's/#DOMAIN#/".$globals->{DOMAIN}."/g'         /etc/squid/squid.conf.in
  sed -i 's/#PROXY#/".$globals->{PROXY}."/g'           /etc/squid/squid.conf.in
  sed -i 's/#DOMAIN#/".$globals->{DOMAIN}."/g'         /etc/squid/squid.primaryschool.in
  sed -i 's/#PROXY#/".$globals->{PROXY}."/g'           /etc/squid/squid.primaryschool.in
  sed -i 's/#LDAPBASE#/".$globals->{LDAPBASE}."/g'     /etc/squid/squid.primaryschool.in
  sed -i 's/#DOMAIN#/".$globals->{DOMAIN}."/g'         /etc/squid/acl_no_caching
  sed -i 's#SERVER_NET#".$globals->{SERVER_NET}."#g'   /etc/squid/acl_server_net
  ln /srv/www/admin/proxy.pac                          /srv/www/admin/proxy.pa
  ln /srv/www/admin/proxy.pac                          /srv/www/admin/wpad.dat
  cp /usr/share/oss/setup/ldap/LDAP_WHITELISTS.ldif    /var/lib/ldap/LDAP_WHITELISTS.ldif
  sed -i 's/#LDAPBASE#/".$globals->{LDAPBASE}."/g'     /var/lib/ldap/LDAP_WHITELISTS.ldif
  /usr/bin/ldapadd -x -c -a -D '".$ldapbinddn."' -y '".$ldappasswd."' -f  /var/lib/ldap/LDAP_WHITELISTS.ldif
";
    if( $globals->{TYPE} eq 'primary'  )
    {
       $todo .= "cp /etc/squid/squid.primaryschool.in /etc/squid/squid.conf";
    }
    else
    {
       $todo .= "cp /etc/squid/squid.conf.in /etc/squid/squid.conf";
    }
    system($todo);
    print DEBUG "###########\n#PROXY SERVER SETUP\n###########\n$todo\n##############\n" if ($debug);
}

sub PostSetup
{
  print STDERR "------ Calling PostSetup ------\n";
   my $todo = '#!/bin/bash -x
#####################
# setup cups
#####################
mv /etc/cups/cupsd.conf /etc/cups/cupsd.conf.orig
cp /etc/cups/cupsd.conf.in /etc/cups/cupsd.conf
grep -q "syntax on" /root/.exrc || echo "syntax on" >> /root/.exrc
#####################
# setup lmd
#####################
cp /etc/my.cnf.in /etc/my.cnf
rcmysql status || rcmysql start
sleep 5
cd /usr/share/lmd/sql
. create-sql.sh
######################
# Make mysql secure
######################
cd /root
echo "set mysql root pwd 1"
password=`mktemp XXXXXXXXXX`
mysqladmin -u root password $password
echo "[client]
host=localhost
user=root
password=$password" > /root/.my.cnf
chmod 600 /root/.my.cnf
echo "set mysql root pwd 2"
mysqladmin -p$password -u root -h `cat /etc/HOSTNAME` password $password
echo "set mysql root pwd 3"
mysqladmin -p$password -u root -h localhost password $password
######################
#Only root and admin may make ssh connection to the server
######################
grep -q "AllowUsers admin root" /etc/ssh/sshd_config || echo "AllowUsers admin root Administrator" >> /etc/ssh/sshd_config
#Setting up smartd services
######################
perl -pi -e \'s/^DEVICESCAN.*$/DEVICESCAN -H -m admin@'.$globals->{DOMAIN}.'/\' /etc/smartd.conf 
chkconfig syslog on
chkconfig apache2 on
chkconfig tomcat6 on
chkconfig ldap on
chkconfig mysql on
chkconfig lmd on
chkconfig xrdp on
if [ "'.$globals->{ISGATE}.'" = "yes" ]
then
	chkconfig rinetd on
fi
chkconfig xinetd on
chkconfig squid  on
chkconfig named  on
chkconfig dhcpd  on
####################
groupmod -A tomcat www
##############################################
#we need the atd daemon for package management
chkconfig atd on
##############################################
#we need the slp daemon for LTSP
chkconfig slpd on
#############################################
# Deaktivate SuSE registration
perl -pi -e \'s/(.*)/#$1/\' /etc/cron.d/novell.com-suse_register
##############################################
# Prepare default profil für linux
mkdir -p /home/profile/linux
cp /usr/share/oss/templates/linux-default-profil /home/profile/linux/default
sed -i "s/#LDAPBASE#/'.$globals->{LDAPBASE}.'/g" /home/profile/linux/default
sed -i "s/#NETWORK#/'.$globals->{NETWORK}.'/g"   /home/profile/linux/default
cp /usr/share/oss/templates/pam_session          /home/profile/linux/pam_session
chmod 755 /home/profile/linux/pam_session
#############################################
# Initialize the system overview
/usr/share/oss/tools/make_data_systemoverview.pl
';
#if ( $globals->{REG_CODE} =~ /([0-9A-F]{4}-[0-9A-F]{4})-([0-9A-F]{4}-[0-9A-F]{4})-[0-9A-F]{4}/ )
#{ #This oss is registered
#	$todo .= "zypper rr 1 2 3 4 5 6;
#sed s/#AUTH#/$1:$2/ /usr/share/oss/templates/repositories > /tmp/repos;
#arch = `uname -m`;
#sed -i s/#ARCH#/\$arch/ /tmp/repos;
#zypper ar -r /tmp/repos; rm /tmp/repos;
#touch /var/adm/oss/registered;
#zypper -n install clax-oss
#";	
#}
   system($todo);
   print DEBUG "###########\n#POST SETUP\n###########\n$todo\n##############\n" if ($debug);
}

sub usage
{
	print "oss_setup.pl --ldappasswd=<path to the file containing the ldappassword>  [<other options>]

	--help		Print this page
	--all		Setup all services and create the initial groups and user accounts
	--ldap		Setup the LDAP server
	--dhcp		Setup the DHCP server
	--dns		Setup the DNS server
	--mail		Setup the MAIL server
	--samba		Setup the SAMBA server
	--proxy		Setup the Proxy server
	--accounts	Create the initial groups and user accounts
	--debug		Provide debug informations

"; 
}
#################### now we start
# Parsing the attributes
my %options    = ();
my $result = GetOptions(\%options,
                      "help",
                      "ldappasswd=s",
                      "all",
                      "ldap",
                      "dns",
                      "dhcp",
                      "samba",
                      "mail",
                      "proxy",
                      "accounts",
                      "debug"
                      );

if (!$result && ($#ARGV != -1))
{
      usage();
      exit 1;
}
if( !defined($options{'ldappasswd'}) )
{
  usage();
  exit 1;
}
$ldappasswd=$options{'ldappasswd'};
if( defined($options{'debug'}) )
{
	$debug = 1;
}
if( defined($options{'all'}) )
{
	$ALL = 1;
}
else
{
	if( defined($options{'mail'}) )
	{
		$MAIL = 1;
	}
	if( defined($options{'proxy'}) )
	{
		$PROXY = 1;
	}
	if( defined($options{'accounts'}) )
	{
		$ACCOUNTS = 1;
	}
	if( defined($options{'samba'}) )
	{
		$SAMBA = 1;
	}
	if( defined($options{'ldap'}) )
	{
		$LDAP = 1;
	}
	if( defined($options{'dns'}) )
	{
		$DNS = 1;
	}
	if( defined($options{'dhcp'}) )
	{
		$DHCP = 1;
	}
}

if($debug)
{
	my $logfile = '/var/adm/backup/setup'.$time;
	open DEBUG,">$logfile";
	chmod 0600, $logfile; 
}

PreSetup();
if( $LDAP || $ALL )
{
	SetupLDAP();
}
if( $DNS || $ALL )
{
	SetupDNS();
}
if( $DHCP || $ALL )
{
	SetupDHCP();
}
if( $MAIL || $ALL )
{
	SetupMail if( ! $is_SUSE );
	system("rcsaslauthd start
	rcpostfix   start
	rccyrus     start
	echo -n 'Waiting for cyrus come up '
	for i in 0 1 2 3 4 5 6 7 8 9; do   sleep 1;   echo -n '.'; done
	echo");
}
if( $SAMBA || $ALL )
{
	SetupSAMBA();
}
if( $ACCOUNTS || $ALL )
{
	$oss_group = oss_group->new({ withIMAP => 1 });
	if( defined $oss_group->{ERROR}->{text} )
	{
		die "ERROR oss_group : ".$oss_group->{ERROR}->{text};
	}
	$oss_user  = oss_user->new({ withIMAP => 1 });
	if( defined $oss_user->{ERROR}->{text} )
	{
		die "ERROR oss_user : ".$oss_user->{ERROR}->{text};
	}
	SetupInitialAccounts();
       $oss_user->{LDAP}->add( dn => 'ou=Computers,'.$oss_user->{LDAP_BASE},
                                attrs =>
                                        [
                                                objectClass  => 'organizationalUnit',
                                                ou           => 'Computers'
                                        ]
                                );
	# Now we create the samba account for root
	my $now         = timelocal(localtime());
        my $passwd    = get_file($ldappasswd);
        chomp $passwd;
	my ( $lm, $nt ) = ntlmgen( $passwd );
	my $SID         = $oss_user->get_attribute("sambaDomainName=$workgroup,".$oss_user->{LDAP_BASE}, 'sambaSID');
	$oss_user->{LDAP}->add( dn => 'uid=root,ou=people,'.$oss_user->{LDAP_BASE},
				attrs =>
                      			[
                         			objectClass  => [ 'account', 'sambaSamAccount' ],
						uid	     => 'root',
						displayName  => 'root',
						sambaNTPassword => $nt,
						sambaPasswordHistory => '0000000000000000000000000000000000000000000000000000000000000000',
						sambaPwdLastSet => $now,
						sambaAcctFlags  => '[U          ]',
						sambaSID        => "$SID-1001"
					]
				);
	# Now we create the accounts for register
	system('useradd -r -s /bin/true -d /tmp register');
	$oss_user->{LDAP}->add( dn => 'uid=register,ou=people,'.$oss_user->{LDAP_BASE},
				attrs =>
                      			[
                         			objectClass  => [ 'account', 'sambaSamAccount' ],
						uid	     => 'register',
						displayName  => 'register',
						sambaNTPassword => 'D29B9F741A059CDE7E9DDFED5701CED7',
						sambaPasswordHistory => '0000000000000000000000000000000000000000000000000000000000000000',
						sambaPwdLastSet => $now,
						sambaAcctFlags  => '[U          ]',
						sambaSID        => "$SID-1002"
					]
				);
	system('net rpc rights grant register SeMachineAccountPrivilege -U root%$( oss_get_admin_pw )');
	$oss_user->add( { uid           => 'printserver$',
                  sn                    => 'Machine account printserver',
                  description           => 'Machine account printserver', 
                  role                  => 'machine',
                  userpassword          => '{crypt}*'
                } );

	system('net rpc -s /etc/samba/printserver.conf -U register%register JOIN');
	$oss_user->destroy();
	$oss_group->destroy();
}
if( $PROXY || $ALL )
{
	SetupProxy();
}
PostSetup();
if($debug)
{
 close DEBUG;
}

