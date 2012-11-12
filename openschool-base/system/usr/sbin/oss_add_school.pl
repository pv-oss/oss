#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use Net::LDAP;
use Net::LDAP::Entry;
use POSIX;
use oss_base;
use oss_utils;
binmode STDIN, ':utf8';
# Global variables;
my $webspace         = 1;
my $filesystem       = 1;
my $uniqueidentifier = '';
my $o                = '';
my $adminpassword    = 'system';
my $NEWBASE          = '';
my $connect       = { withIMAP => 1 };
my @needed_groups    = ('teachers','students','sysadmins','administration');


# TODO Translation into .ini file
my $Translations = {
                         "EN" => { "classname"      => "Class",
                                   "teachers"       => "Teachers",
                                   "students"       => "Students",
                                   "administration" => "Administration",
                                   "webadmins"      => "Web administrators",
                                   "sysadmins"      => "System administrators",
                                   "rooms"          => "Rooms"
                                 },
                         "DE" => { "classname"      => "Klasse",
                                   "teachers"       => "Lehrer",
                                   "students"       => "Schüler",
                                   "administration" => "Verwaltung",
                                   "webadmins"      => "Webadministratoren",
                                   "sysadmins"      => "Systemadministratoren",
                                   "rooms"          => "Räume"
                                 },
                         "HU" => { "classname"      => "Osztály",
                                   "teachers"       => "Tanárok",
                                   "students"       => "Diákok",
                                   "administration" => "Adminisztráció",
                                   "webadmins"      => "Webadministrátorok",
                                   "sysadmins"      => "Rendszergazdák",
                                   "rooms"          => "Termek"
                                 }
                      };

# Make LDAP Connection
my $oss = oss_base->new();
my $DEBUG               = 0;
if( $oss->get_school_config('SCHOOL_DEBUG') eq 'yes' )
{
  $DEBUG = 1;
}

my %SYSCONFIG = %{$oss->{SYSCONFIG}};
$oss->destroy();

open(OUT,">/tmp/add_school1") if ($DEBUG);

my $ENTRY = Net::LDAP::Entry->new;

while(<STDIN>){

    print OUT if ($DEBUG);

    # Clean up the line!
    chomp; s/^\s+//; s/\s+$//;

    my ( $key, $value ) = split / /,$_,2;

    next if( getConnect($connect,$key,$value));

    if( $key eq 'webspace' )
    {
      if ( $value =~ /yes/i )
      {
          $webspace = 1;
      }
    }
    elsif ( $key =~ /^SCHOOL_/ )
    {
      $SYSCONFIG{$key} = $value;
    }
    elsif ( $key eq 'adminpassword'  )
    {
      $adminpassword = $value;
    }
    else
    {
      # TODO remove it if it is fixed by pg
      if( $key =~ /country/i )
      {
          $ENTRY->add( 'c' => "$value" );
          next;
      }
      # They are LDAP Parameter      
      $ENTRY->add( $key => "$value" );
      #uniqueidentifier, and o need we
      if( $key =~ /uniqueidentifier/i )
      {
      	$uniqueidentifier = $value;
      }
      elsif( $key =~ /^o$/i )
      {
      	$o = $value;
      }
    }
}

# Make OSS Connection
if( defined $ENV{SUDO_USER} )
{
   if( ! defined $connect->{aDN} || ! defined $connect->{aPW} )
   {
       die "Using sudo you have to define the parameters aDN and aPW\n";
   }
}
my $baseatrrs = "aDN ".$connect->{aDN}."\naPW ".$connect->{aPW}."\n";
my $oss = oss_base->new($connect);

$ENTRY->add( objectclass => 'organization' ,
	     objectclass => 'school' );

$NEWBASE = 'uniqueidentifier='.$uniqueidentifier.','.$oss->{LDAP_BASE};
$ENTRY->dn($NEWBASE);
my $mesg = $oss->{LDAP}->add($ENTRY);
$oss->ldap_error($mesg);
# 
my $LANG = $SYSCONFIG{SCHOOL_LANG} || 'DE'; 

#Create the DNS-Entry
#First we get the default settings: zoneName=realschule-bayern.info
my $mesg = $oss->{LDAP}->search(  
			base   => "zoneName=realschule-bayern.info,ou=DNS,$oss->{LDAP_BASE}",
                        scope  => 'base',
                        filter => "objectclass=dNSZone" );
# get out SOA and increase serial number
my $zone_entry = $mesg->entry(0);
my $soa = $zone_entry->get_value("sOARecord");
my @soa = split(/ /,$soa);
my $timestamp = $soa[2];
my $sernr  = substr($timestamp, 8, 2);
my $timenr = substr($timestamp, 0, 8);
my $timenow = strftime("%Y%m%d",localtime);
my $sernr    = '00';
my $timenr   = $timenow;
my $sOARecord= $soa[0]." ".$soa[1]." ".$timenr.$sernr." ".$soa[3]." ".$soa[4]." ".$soa[5]." ".$soa[6];
my $dNSTTL   = $zone_entry->get_value('dNSTTL');
my @mXRecord = $zone_entry->get_value('mXRecord');
my @nSRecord = $zone_entry->get_value('nSRecord');

$ENTRY = Net::LDAP::Entry->new;
$ENTRY->add( objectclass => 'dNSZone',
	     objectclass => 'mailDomain'
	   );
$ENTRY->add( zoneName           => $SYSCONFIG{SCHOOL_DOMAIN} ,
	     dNSClass           => 'IN',
	     dNSTTL          => $dNSTTL,
             sOARecord       => $sOARecord,
             mXRecord        => \@mXRecord,
             nSRecord        => \@nSRecord,
	     relativeDomainName => '@',
	     mailDomainType     => 'virtual',
	     mailDomainMasquerading => 'yes',
	   );
$ENTRY->dn( "zoneName=".$SYSCONFIG{SCHOOL_DOMAIN}.",ou=DNS,$oss->{LDAP_BASE}" );
$oss->{LDAP}->add($ENTRY);

$oss->add_host('mail.'.$SYSCONFIG{SCHOOL_DOMAIN},"$SYSCONFIG{SCHOOL_MAILSERVER}"); 

if( $webspace )
{
  if ( !$oss->add_host('www.'.$SYSCONFIG{SCHOOL_DOMAIN},"$SYSCONFIG{SCHOOL_SERVER}") )
  {
     print OUT $oss->{ERROR}->{text} if($DEBUG);
  }
}

#Create the subentries:
#ou=sysconfig
$ENTRY = Net::LDAP::Entry->new;
$ENTRY->add( objectclass => 'top',
	     objectclass => 'organizationalUnit'
	   );
$ENTRY->add( ou => 'sysconfig' );
$ENTRY->dn( "ou=sysconfig,$NEWBASE" );
$oss->{LDAP}->add($ENTRY);
#Create the school configuration entries
if( !defined $SYSCONFIG{SCHOOL_LOGIN_PREFIX} || $SYSCONFIG{SCHOOL_LOGIN_PREFIX} =~ /^default/i )
{
  $SYSCONFIG{SCHOOL_LOGIN_PREFIX} = $uniqueidentifier."-";
}
if( !defined $SYSCONFIG{SCHOOL_GROUP_PREFIX} || $SYSCONFIG{SCHOOL_GROUP_PREFIX} =~ /^default/i )
{
  $SYSCONFIG{SCHOOL_GROUP_PREFIX} = $uniqueidentifier."-";
}
if( !defined $SYSCONFIG{SCHOOL_HOME_BASE} || $SYSCONFIG{SCHOOL_HOME_BASE} =~ /^default/i )
{
  $SYSCONFIG{SCHOOL_HOME_BASE} = "/home/".$uniqueidentifier;
}
$SYSCONFIG{SCHOOL_HOME_BASE} =~ s/\/$//;

$SYSCONFIG{USER_BASE}  = 'ou=people,'.$NEWBASE;
$SYSCONFIG{GROUP_BASE} = 'ou=group,'.$NEWBASE;

foreach my $key ( keys %SYSCONFIG )
{
  $ENTRY = Net::LDAP::Entry->new;
  $ENTRY->add( objectclass => 'SchoolConfiguration');
  $ENTRY->add( configurationKey   => $key,
	       configurationValue => $SYSCONFIG{$key} );
  $ENTRY->dn( "configurationKey=$key,ou=sysconfig,$NEWBASE" );
  $oss->{LDAP}->add($ENTRY);
}
#ou=people
$ENTRY = Net::LDAP::Entry->new;
$ENTRY->add( objectclass => 'top',
	     objectclass => 'organizationalUnit'
	   );
$ENTRY->add( ou => 'people' );
$ENTRY->dn( "ou=people,$NEWBASE" );
$oss->{LDAP}->add($ENTRY);
#ou=group
$ENTRY = Net::LDAP::Entry->new;
$ENTRY->add( objectclass => 'top',
	     objectclass => 'organizationalUnit'
	   );
$ENTRY->add( ou => 'group' );
$ENTRY->dn( "ou=group,$NEWBASE" );
$oss->{LDAP}->add($ENTRY);
#ou=resourceObjects
$ENTRY = Net::LDAP::Entry->new;
$ENTRY->add( objectclass => 'top',
	     objectclass => 'organizationalUnit'
	   );
$ENTRY->add( ou => 'resourceObjects' );
$ENTRY->dn( "ou=resourceObjects,$NEWBASE" );
$oss->{LDAP}->add($ENTRY);
#ou=computers
$ENTRY = Net::LDAP::Entry->new;
$ENTRY->add( objectclass => 'top',
	     objectclass => 'organizationalUnit'
	   );
$ENTRY->add( ou => 'computers' );
$ENTRY->dn( "ou=computers,$NEWBASE" );
$oss->{LDAP}->add($ENTRY);
#ou=ldmap
$ENTRY = Net::LDAP::Entry->new;
$ENTRY->add( objectclass => 'top',
	     objectclass => 'organizationalUnit'
	   );
$ENTRY->add( ou => 'ldmap' );
$ENTRY->dn( "ou=ldmap,$NEWBASE" );
$oss->{LDAP}->add($ENTRY);
#ou=DHCP
$ENTRY = Net::LDAP::Entry->new;
$ENTRY->add( objectclass => 'top',
	     objectclass => 'organizationalUnit'
	   );
$ENTRY->add( ou => 'DHCP' );
$ENTRY->dn( "ou=DHCP,$NEWBASE" );
$oss->{LDAP}->add($ENTRY);
#ou=DNS
$ENTRY = Net::LDAP::Entry->new;
$ENTRY->add( objectclass => 'top',
	     objectclass => 'organizationalUnit'
	   );
$ENTRY->add( ou => 'DNS' );
$ENTRY->dn( "ou=DNS,$NEWBASE" );
$oss->{LDAP}->add($ENTRY);

#Create the filesystem entries
if( $filesystem )
{
  system( "/usr/sbin/oss_create_school_home ".$SYSCONFIG{SCHOOL_HOME_BASE});
}

#Create some default groups:
foreach my $group (@needed_groups)
{
  my $args  = $baseatrrs."oid $uniqueidentifier\n";
     $args .= "cn $group\n"; 
     $args .= "grouptype primary\n";
     $args .= "description ".$Translations->{$LANG}->{$group}." $o\n";
     $args .= "role $group\n";
     $args .= "mDN uid=".$SYSCONFIG{SCHOOL_LOGIN_PREFIX}."admin,ou=people,".$NEWBASE."\n";
  my $ERR = cmd_pipe("/usr/sbin/oss_add_group.pl",$args);
  print OUT "Creating $group: $ERR\n" if($DEBUG);
}

#Create the main administrator
my $args  = $baseatrrs."oid $uniqueidentifier\n";
$args .= "uid admin\n";
$args .= "sn Systemadministrator\n";
$args .= "givenname $uniqueidentifier\n";
$args .= "userpassword $adminpassword\n";
$args .= "birthday 1970-01-01\n";
$args .= "mail admin\n";
$args .= "role sysadmins\n";

print OUT $args if ($DEBUG);

my $ERR = cmd_pipe("/usr/sbin/oss_add_user.pl",$args);
print OUT "Creating admin: $ERR\n" if($DEBUG);

#Create the webspace entries
if( $webspace )
{

  my $args  = $baseatrrs."oid $uniqueidentifier\n";
     $args .= "cn webadmins\n"; 
     $args .= "grouptype primary\n";
     $args .= "description ".$Translations->{$LANG}->{webadmins}." $o\n";
     $args .= "role webadmins\n";
     $args .= "mDN uid=".$SYSCONFIG{SCHOOL_LOGIN_PREFIX}."admin,ou=people,".$NEWBASE."\n";
     $args .= "mDN uid=".$SYSCONFIG{SCHOOL_LOGIN_PREFIX}."webadmin,ou=people,".$NEWBASE."\n";
     $args .= "mUID ".$SYSCONFIG{SCHOOL_LOGIN_PREFIX}."webadmin\n";
  my $ERR = cmd_pipe("/usr/sbin/oss_add_group.pl",$args);
  print OUT "Creating webadmins: $ERR\n" if($DEBUG);
  my $docroot     =  $SYSCONFIG{SCHOOL_HOME_BASE}."/groups/WEBADMINS/htdocs";
  my $command = "/bin/cp /etc/apache2/vhosts.d/oss_vhost.template /etc/apache2/vhosts.d/$SYSCONFIG{SCHOOL_DOMAIN}.conf
/usr/bin/setfacl -m u:wwwrun:rx $SYSCONFIG{SCHOOL_HOME_BASE}/groups/WEBADMINS;
/bin/mkdir -m 2770 -p $docroot
/usr/bin/setfacl -m u:wwwrun:rx $docroot;
/usr/bin/setfacl -d -m u:wwwrun:rx $docroot;
/usr/bin/perl -pi -e 's#DOMAIN#$SYSCONFIG{SCHOOL_DOMAIN}#' /etc/apache2/vhosts.d/$SYSCONFIG{SCHOOL_DOMAIN}.conf
/usr/bin/perl -pi -e 's#DOCROOT#$docroot#' /etc/apache2/vhosts.d/$SYSCONFIG{SCHOOL_DOMAIN}.conf
";
   system($command);

   #Create the main administrator
   $args  = $baseatrrs."oid $uniqueidentifier\n";
   $args .= "uid webadmin\n";
   $args .= "sn Webadministrator\n";
   $args .= "givenname $uniqueidentifier\n";
   $args .= "userpassword $adminpassword\n";
   $args .= "birthday 1970-01-01\n";
   $args .= "mail webadmin\n";
   $args .= "role webadmins\n";

   print OUT $args if ($DEBUG);

   $ERR = cmd_pipe("/usr/sbin/oss_add_user.pl",$args);
   print OUT "Creating webadmin: $ERR\n" if($DEBUG);

   #Starting the plugins
   my $TMP = `echo "oid $uniqueidentifier" | /usr/sbin/oss_get_school.pl text`;
   chomp $TMP;
   $TMP .= "adminpassword $adminpassword\n\n";
   my $TMPFILE = write_tmp_file($TMP);
   system("/usr/share/oss/plugins/plugin_handler.sh add_school $TMPFILE");

}
close OUT if ($DEBUG);

system("/etc/init.d/named   restart &> /dev/null");

if( $webspace )
{
  system("/etc/init.d/apache2 reload &> /dev/null");
}

print $oss->replydn($NEWBASE);
$oss->destroy();
