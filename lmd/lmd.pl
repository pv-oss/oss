#!/usr/bin/perl
#
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2007 - 2009  Peter Varkoly <peter@varkoly.de>, Fürth.  All rights reserved.
#
# $Id: lmd.pl pv Exp $
#
#
=head1 NAME

 lmd.pl
 
=head1 PREFACE

 Linux System Managemant Daemon

=head1 DESCRIPTION

This daemon serves for managemant capabilities for SUSE Linux Systems.
This daemon listens on a TCP-IP port and accepts XML streams over SSL.

=cut

BEGIN
{ 
	push @INC,"/usr/share/lmd/alibs/";
	push @INC,"/usr/share/oss/lib/";
}

$| = 1; # do not buffer stdout

use strict;
use Getopt::Long;
use Config::IniFiles;
use XML::Parser;
use XML::Writer;
use Data::Dumper;
use IO::Socket::UNIX;
use IO::Socket::SSL;
use DBI;
use DBI qw(:utils);
use oss_base;
use oss_utils;
use Digest::MD5  qw(md5_hex);
use MIME::Base64;
use Storable qw(thaw freeze);
use Crypt::OpenSSL::RSA;
use utf8;
use Encode ( 'encode', 'decode' );

##############################################################################
# Define Global Variable
##############################################################################

# Loggin / Debugging
my $LOGDIR	= "/var/log/";
my $PIDFILE	= "/var/run/lmd.pid";
my $TIMEZONE	= `date +%:z`;
my $DEBUG	= 0;

my $xreply	= undef;
# Variable for the socket communication
my $SERVER;
my $CLIENT;
my $PORT	= "1967";
my $ADDRESS	= "0.0.0.0";
my $SOCKET	= "/var/run/lmd.sock";

# Data
my $APPLICATION	= undef;
my $ACTION	= undef;
my $TABLE       = undef;
my $LINE        = undef;
my $VARIABLE    = undef;
my $VALUE	= undef;
my $SESSIONID   = undef;
my $STIME	= 90*60;
my $REMOTEIP    = undef;
my $DBH		= undef;
my $PRINTSERVER_LOCAL= 1;
my $MAILSERVER_LOCAL = 1;
my $PROXYSERVER_LOCAL= 1;
my $REQUEST	= {};
my $SHREQUEST	= '';
my $CAPABILITIES= {
	LMD => { allowedRole => [ 'all' ] }
   };
my $INTERFACE	= { 
	LMD =>  { 
		AddSessionDatas    => 'intern',
		GetSessionDatas    => 'intern',
		DeleteSessionDatas => 'intern',
		UpdateSessionDatas => 'intern',
		GetSessionValue    => 'intern',
		UpdateSessionTime  => 'intern',
		trans              => 'intern'
	}
};
my $VARIABLES	= {};
my $MENU	= {};
my $LANG	= 'EN';
my @DISABLED    = ();
my %ATTRIBUTES  = ();
#TODO Make it configrable
my %ROLEMAP     = ( MUSICTEACHERS => 'teachers' , 'administration' => 'teachers', 'administration,sysadmins' => 'teachers,sysadmins' );


#Parsing Command Line Parameter
my %options = ();
my $result  = GetOptions( \%options, "port=s", "address=s", "stime=s", "disabled=s","debug", "init", "help" );
if (!$result || $options{'help'})
{
	usage();
	exit 1;
}
@DISABLED= split /,/,$options{'disabled'}	if( defined $options{'disabled'} );
$PORT    = $options{'port'}			if( defined $options{'port'} );
$ADDRESS = $options{'address'}			if( defined $options{'address'} );
$STIME   = $options{'stime'} * 60		if( defined $options{'stime'} );
$DEBUG   = 1					if( defined $options{'debug'} );

#remove unix socket if any exists and we have to use it
unlink "/var/run/lmd.sock" if ( -e "/var/run/lmd.sock" && $ADDRESS eq 'unix' );

#Initialize the random number generator
srand;

#Read some LMD settings from /etc/sysconfig/lmd
my ( $APPS_NOT_TO_ARCHIVE, $APPS_TO_ARCHIVE, $ARCHIVE_REQUESTS, $ORDER, $DBCON, $DBUSER, $DBPW, $SAVE_PASSWORD_IN_DB ) = 
	parse_file( "/etc/sysconfig/lmd", 
	"LMD_APPLICATIONS_NOT_TO_ARCHIVE=",
       	"LMD_APPLICATIONS_TO_ARCHIVE=",
       	"LMD_ARCHIVE_REQUESTS=",
       	"LMD_CATEGORY_ORDER=",
       	"LMD_DB_CONNECTION=",
       	"LMD_DB_USER=",
       	"LMD_DB_PW=",
	"LMD_SAVE_PASSWORD_IN_DB=");
$ARCHIVE_REQUESTS = ( $ARCHIVE_REQUESTS eq 'yes' ) ? 1:0;
my @CATEGORIES = split /,/,$ORDER;

#Make DB Connection;
if( ! $DBCON )
{
	$DBCON = 'dbi:mysql:lmd';
	$DBUSER= 'root';
	($DBPW)= parse_file('/root/.my.cnf',"password=");
}
$DBH = DBI->connect( $DBCON, $DBUSER, $DBPW);
$DBH->do("SET CHARACTER SET utf8");
$DBH->do("SET NAMES utf8");

$ENV{LC_ALL} = '';

if( defined $options{'init'} )
{ 
	#Generate SSL-Keys for saving passworts
	if( ! -e '/root/.ssh/lmd.keys' )
	{
		my $rsa  = Crypt::OpenSSL::RSA->generate_key(1024);
		my $tmp  = $rsa->get_public_key_string();
		$tmp    .= $rsa->get_private_key_string();
		write_file('/root/.ssh/lmd.keys',$tmp);
		chmod 0600, '/root/.ssh/lmd.keys';
	}
	#Initialize the applications
	for my $i ( glob("/usr/share/lmd/alibs/*sh") )
	{  #This is a shell module
	    $i =~ /\/usr\/share\/lmd\/alibs\/(.*)\.sh/;
	    my $modul = $1;
	    # Disabled
	    next if ( contains($modul,\@DISABLED) );
	    Debug("Loading alibs shell modul $i ...\n");
	    my $o     = cmd_pipe("$i getCapabilities","");
	    foreach my $tag ( split /\n/, $o )
	    {
		my ($k, $v) = split /\s+/,$tag,2;
		if( $k eq 'variable' )
		{
		    my ($name, $desc) = split /\s+/,$v,2;
		    $VARIABLES->{$modul}->{$name} = eval $desc;
		}
		else
		{
		    push @{$CAPABILITIES->{$modul}->{$k}},  $v;
		}
	    }
	    next if( defined $CAPABILITIES->{$modul}->{disabled}->[0] );
	    foreach my $r ( @{$CAPABILITIES->{$modul}->{allowedRole}} )
	    {
		next if( ! isModuleAllowed('r',$r,$modul) );
		my %menu = ();
		$menu{title} = $CAPABILITIES->{$modul}->{title}->[0];
		if( defined $CAPABILITIES->{$modul}->{help} )
		{
		    $menu{help} = $CAPABILITIES->{$modul}->{help}->[0];
		}
		$menu{order} = $CAPABILITIES->{$modul}->{order} ? $CAPABILITIES->{$modul}->{order}->[0] : 1000;
		$MENU->{$r}->{$CAPABILITIES->{$modul}->{category}->[0]}->{$modul} = \%menu;
	    }
	    $o     = `echo "" | $i interface`;
	    foreach my $action ( split /\s+/,$o)
	    {
		$INTERFACE->{$modul}->{$action} = $i;
	    }
	}
	for my $i ( glob("/usr/share/lmd/alibs/*pm") )
	{   #This is a perl module
	    $i =~ /\/usr\/share\/lmd\/alibs\/(.*)\.pm/;
	    my $modul = $1;
	    # Disabled
	    next if ( contains($modul,\@DISABLED) );

	    Debug("Loading alibs perl modul $modul ...\n");
	    require "$modul.pm";

	    my $result = $modul->getCapabilities($modul);
	    # module disable itself
	    next if ( ! defined $result );
	    foreach my $tag (@{$result})
	    {
		my $tagName = (keys(%{$tag}))[0];
		if( $tagName  eq 'variable' )
		{
		    my $variable = $tag->{variable};
		    my $name     = $variable->[0];
		    my $desc     = $variable->[1];
		    $VARIABLES->{$modul}->{$name} = $desc;
		}
		else
		{
			if( ref $tag->{$tagName} eq 'ARRAY' )
			{
				push @{$CAPABILITIES->{$modul}->{$tagName}},  @{$tag->{$tagName}};
			}
			else
			{
				push @{$CAPABILITIES->{$modul}->{$tagName}},  $tag->{$tagName};
			}
		}
	    }
	    next if( defined $CAPABILITIES->{$modul}->{disabled}->[0] );
	    #Generate Menu
	    foreach my $r ( @{$CAPABILITIES->{$modul}->{allowedRole}} )
	    {
		next if( ! isModuleAllowed('r',$r,$modul) );
		my %menu = ();
		$menu{title} = $CAPABILITIES->{$modul}->{title}->[0];
		if( defined $CAPABILITIES->{$modul}->{help} )
		{
		    $menu{help} = $CAPABILITIES->{$modul}->{help}->[0];
		}
		$menu{order} = $CAPABILITIES->{$modul}->{order} ? $CAPABILITIES->{$modul}->{order}->[0] : 1000;
		$MENU->{$r}->{$CAPABILITIES->{$modul}->{category}->[0]}->{$modul} = \%menu;
	    }
	    my $tmp = $modul->interface;
	    foreach my $action (@{$tmp})
	    {
		$INTERFACE->{$modul}->{$action} = 'perl';
	    }
	}
	#Some debug
	#print '1.1'.Dumper($INTERFACE)    if $DEBUG;
	print '1.2'.Dumper($MENU)         if $DEBUG;
	#print '1.3'.Dumper($CAPABILITIES) if $DEBUG;
	#print '1.4'.Dumper($VARIABLES)    if $DEBUG;

	#Initialize the translations
	$DBH->do("DELETE from lang");
	AddSessionDatas(encode_base64(freeze($INTERFACE),''),'INTERFACE','BASE');
	AddSessionDatas(encode_base64(freeze($CAPABILITIES),''),'CAPABILITIES','BASE');
	AddSessionDatas(encode_base64(freeze($VARIABLES),''),'VARIABLES','BASE');
	AddSessionDatas(encode_base64(freeze($MENU),''),'MENU','BASE');
	foreach my $f ( glob("/usr/share/lmd/lang/*ini") )
	{
		if( $f =~ /\/usr\/share\/lmd\/lang\/[^_]+_(.*)\.ini/ )
		{
			my $lang = $1;
			my $m = new Config::IniFiles( -file => $f );
			if( $m )
			{
				foreach my $section ( $m->Sections )
				{
					foreach my $par ( $m->Parameters($section) )
					{
						my $val = $m->val($section,$par);
						$par =~ s/'/\\'/g;
						$val =~ s/'/\\'/g;
						foreach my $s ( split /\|/, $section)
						{
							if( ! $DBH->do("INSERT INTO lang VALUES ('$lang','$s','$par','$val')") )
							{
							    print STDERR "ERROR BY: INSERT INTO lang VALUES ('$lang','$s','$par','$val')\n";
							}
						}
					}
				}
			}
			else
			{
				print STDERR "ERROR can not read $f\n";
			}
		}
	}
	$DBH->disconnect;
	exit 0;
}

my $key         = get_file('/root/.ssh/lmd.keys');
my $RSA_PUBLIC  = Crypt::OpenSSL::RSA->new_public_key($key);
my $RSA_PRIVATE = Crypt::OpenSSL::RSA->new_private_key($key);


$VARIABLES=thaw(decode_base64(GetSessionDatas('VARIABLES','BASE')));
$MENU=thaw(decode_base64(GetSessionDatas('MENU','BASE')));
$INTERFACE=thaw(decode_base64(GetSessionDatas('INTERFACE','BASE')));
$CAPABILITIES=thaw(decode_base64(GetSessionDatas('CAPABILITIES','BASE')));
$DBH->disconnect;

#Now looks which server are local
my $test = `. /etc/sysconfig/schoolserver; /sbin/ip addr | grep "\$SCHOOL_PRINTSERVER/"`;
chomp $test;
$PRINTSERVER_LOCAL = 0 if( !$test );
$test = `. /etc/sysconfig/schoolserver; /sbin/ip addr | grep "\$SCHOOL_MAILSERVER/"`;
chomp $test;
$MAILSERVER_LOCAL = 0 if( !$test );
$test = `. /etc/sysconfig/schoolserver; /sbin/ip addr | grep "\$SCHOOL_PROXY/"`;
chomp $test;
$PROXYSERVER_LOCAL = 0 if( !$test );

#Daemonize if not DEBUG
$SIG{CHLD} = 'IGNORE';
daemonize();

#start the socket
if( $ADDRESS eq "unix" )
{
    $SERVER = IO::Socket::UNIX->new(
        Listen          => 1,
        Type            => SOCK_STREAM,
        Local           => $SOCKET
    );
    chmod 0777, $SOCKET;
}
else
{
    $SERVER = IO::Socket::SSL->new(
        Listen          => 1,
        LocalAddr       => $ADDRESS,
        LocalPort       => $PORT,
        Proto           => 'tcp',
        Reuse           => 1,
        SSL_key_file    => '/etc/ssl/servercerts/serverkey.pem',
        SSL_cert_file   => '/etc/ssl/servercerts/servercert.pem',
        SSL_ca_file     => '/etc/ssl/certs/YaST-CA.pem',
        SSL_use_cert    => 1,
        SSL_verify_mode => 0x01,
        Type            => SOCK_STREAM
    );
}

if( ! defined $SERVER ) {
    print STDERR "ERRNO=<$!> in my_connect\n";
}

Debug ("Socket started\n");


while( 1 )
{
   next unless $CLIENT = $SERVER->accept();
   my $child = fork;
   if ($child == 0)
   {
      handle_conn();
   }
}

##############################################################################
#   Definition of Subroutines                                                #
##############################################################################

sub handle_conn
{
    $DBH = DBI->connect( $DBCON, $DBUSER, $DBPW);
    $DBH->do("SET CHARACTER SET utf8");
    $DBH->do("SET NAMES utf8");
    Debug( xml_time() );
    if( $ADDRESS ne "unix" )
    { 
        Debug(" Connection from ".$CLIENT->peerhost()."\n");
    }
    else
    {
        Debug(" Connection via unix socket\n");
    }

    # Start a new XML parser
    my $p1 = new XML::Parser(Style => 'Stream');
    $xreply    = undef;
    my $XML    = '';
    my $tmp    = '';
    my $package_length = 0;
    my $pl     = 16384;
    my $read   = 0;

    #reading package length from client
    sysread $CLIENT, $package_length, 4;
    $package_length = unpack("l", $package_length);
    Debug("$package_length byte package is expected from client.\n");
    if( $package_length < 16384 )
    {
    	$pl = $package_length;
    }

    while( $read = sysread( $CLIENT , $tmp, $pl ) )
    {
    	$package_length -= $read;
	if( $package_length < 16384 )
	{
		$pl = $package_length;
	}
    	$XML .= $tmp;
	$tmp = '';
	last if( !$pl);
    }
    Debug("XML got from client:\n\n".$XML);

    $p1->parse($XML,ProtocolEncoding => 'UTF-8');
    close $CLIENT;
    $DBH->disconnect;
    exit;
}

sub AddTranslation
{
    my ( $lang, $sec, $str, $val ) = @_;
    $str =~ s/'/\\'/g;
    $val =~ s/'/\\'/g;
    my $rows  = $DBH->prepare("SELECT * FROM  missedlang WHERE lang='$lang' AND section='$sec' AND  string='$str'");
    $rows->execute;
    my $rowsvalue = $rows->fetch();

    if( ! $rowsvalue->[0] ){
        $DBH->do("INSERT missedlang  VALUES ('$lang','$sec','$str','$val')");
    }elsif($rowsvalue->[0]){
        $DBH->do("UPDATE missedlang SET value='$val' WHERE lang='$lang' AND section='$sec' AND  string='$str'");
    }

=item
    my ( $lang, $sec, $str, $val ) = @_;
    my $rows = $DBH->do("UPDATE missedlang SET value='$val' WHERE lang='$lang' AND section='$sec' AND  string='$str'");
    if( ! $rows )
    {
    	$DBH->do("INSERT missedlang  VALUES ('$lang','$sec','$str','$val')");
    }
=cut
}

sub GetSessionValue
{
    my $what = shift;

    my $sel  = $DBH->prepare("SELECT $what FROM sessions WHERE id='$SESSIONID'");
    $sel->execute;
    my $value = $sel->fetch();
    return undef if( ! defined $value->[0] );

    if( $what eq 'userpassword' )
    {
    	return $RSA_PRIVATE->decrypt(decode_base64($value->[0]));
    }
    return $value->[0];

}

sub UpdateSessionTime
{
    $DBH->do("UPDATE sessions SET lastaction='".time."' WHERE id='$SESSIONID'");
}

sub UpdateSessionData
{
    my $what  = shift;
    my $value = shift;
    $DBH->do("UPDATE sessions SET $what='".$value."' WHERE id='$SESSIONID'");
}

sub DeleteSessionDatas
{
    my $var   = shift || 'default';
    my $ses   = shift || $SESSIONID;
    my $sel   = $DBH->prepare("DELETE FROM sessiondata WHERE id='$ses' AND variable='$var'");
    $sel->execute;
    my $value = $sel->fetch();
    return $value->[0];

}

sub GetSessionDatas
{
    my $var   = shift || 'default';
    my $ses   = shift || $SESSIONID;
    my $sel   = $DBH->prepare("SELECT value FROM sessiondata WHERE id='$ses' AND variable='$var'");
    $sel->execute;
    my $value = $sel->fetch();
    return $value->[0];

}

sub AddSessionDatas
{
    my $value = shift;
    my $var   = shift || 'default';
    my $ses   = shift || $SESSIONID;
    $value =~ s/'/\\'/g;
    $var   =~ s/'/\\'/g;
    my $sel   = $DBH->prepare("SELECT value FROM sessiondata WHERE id='$ses' AND variable='$var'");
    $sel->execute;
    my $rows = $sel->rows;
    if( $rows )
    {
       $DBH->do("UPDATE sessiondata SET value='$value' WHERE id='$ses' AND variable='$var'");
    }
    else
    {
       $DBH->do("INSERT INTO sessiondata VALUES ('$ses','$var','$value')");
    }
}

sub isModuleAllowed($$$)
{
	my ( $type, $owner, $module ) = @_;
	my $Category = $CAPABILITIES->{$module}->{category}->[0];
	my $sel  = $DBH->prepare("SELECT `right` FROM acls WHERE type='$type' AND owner='$owner' AND destination='C:$Category'" );
	$sel->execute;
	my $value = $sel->fetch();
	if( defined $value->[0] && $value->[0] eq 'n' )
	{
		return 0;
	}
	$sel  = $DBH->prepare("SELECT `right` FROM acls WHERE type='$type' AND owner='$owner' AND destination='$module'" );
	$sel->execute;
	my $value = $sel->fetch();
	if( defined $value->[0] && $value->[0] eq 'n' )
	{
		return 0;
	}
        $sel  = $DBH->prepare("SELECT `right` FROM acls WHERE type='$type' AND owner='*' AND destination='$module'" );
        $sel->execute;
        my $value = $sel->fetch();
        if( defined $value->[0] && $value->[0] eq 'n' )
        {
                return 0;
        }
	return 1;
}

sub isAllowed
{
	my $dest = shift;
	my $dn   = GetSessionValue('dn');
	my $role = GetSessionValue('role');

	my $sel  = $DBH->prepare("SELECT `right` FROM acls WHERE type='u' AND owner='$dn' AND destination='$dest'" );
	$sel->execute;
	my $value = $sel->fetch();
	if( defined $value->[0] )
	{
		return ( $value->[0] eq 'n' ) ? 0 : 1 ;
	}
	$sel  = $DBH->prepare("SELECT `right` FROM acls WHERE type='r' AND owner='$role' AND destination='$dest'" );
	$sel->execute;
	$value = $sel->fetch();
	if( defined $value->[0] )
	{
		return ( $value->[0] eq 'n' ) ? 0 : 1 ;
	}
	$sel  = $DBH->prepare("SELECT `right` FROM acls WHERE type='r' AND owner='*' AND destination='$dest'" );
	$sel->execute;
	$value = $sel->fetch();
	if( defined $value->[0] )
	{
		return ( $value->[0] eq 'n' ) ? 0 : 1 ;
	}
	return 1;
}

#########################################
# START Soubrutines for the xml parsing #
#########################################
sub StartTag
{
    my ( $v1, $v2 ) = @_;
    %ATTRIBUTES = %_;
    #Debug('ATTRIBUTES: '.Dumper(\%ATTRIBUTES));
    if( $v2 eq 'request' )
    {
        if( defined $_{name} )
        {
            $ACTION = $_{name};
            if( defined $_{line} && $_{line} ne '' )
            {
		$REQUEST->{line} = $_{line};	
	    }
            if( defined $_{table} && $_{table} ne '' )
            {
		$REQUEST->{table} = $_{table};	
	    }
        }
	else
	{
	    RequestError('1');
	}
        if( defined $_{application} )
        {
            $APPLICATION = $_{application};
	    if( ! defined $INTERFACE->{$APPLICATION}  && $ACTION ne 'getMenu' && $APPLICATION ne 'OSS_BASE'  )
	    {
	        RequestError('2');
	    }
        }
        if( defined $_{sessionID} )
        {
            $SESSIONID = $_{sessionID};
	}
        if( defined $_{ip} )
        {
            $REMOTEIP = $_{ip};
	}
        # Debug("APPLICATION $APPLICATION ACTION $ACTION\n");
	# Check if this is a valid request:
	if( $APPLICATION ne 'OSS_BASE' && $ACTION ne 'login' )
	{
	    RequestError('4') if( !defined $SESSIONID || $SESSIONID ne GetSessionValue('id'));
	    my $diff = time - GetSessionValue('lastaction');
	    RequestError('5') if( $diff  > $STIME );
	    #RequestError('6') if( $REMOTEIP ne GetSessionValue('ip'));
	    RequestError('7') if( ! check_rights() );
            UpdateSessionTime();
	}
    }
    elsif( $ACTION )
    {
	next if ( $v2 eq 'VALUE' );
        $VARIABLE  = $v2;
        if( defined $_{line} && $_{line} ne '' )
        {
		$LINE  = $_{line};
	}
        if( defined $_{table} && $_{table} ne '' )
	{
		$TABLE  = $_{table};
	}
        #Debug("  START VARIABLE $TABLE $LINE $VARIABLE");
    }
}

sub Text
{
    chomp;
#   if(  defined $VARIABLES->{$APPLICATION}->{$VARIABLE} && 
#	$VARIABLES->{$APPLICATION}->{$VARIABLE}->[1] eq 'boolean' &&
#	$VALUE eq 'false' )
#   {
#   	$VALUE = 0;
#   }
    $VALUE = $_;
#    utf8::upgrade($VALUE);
    $VALUE = encode("utf8", $VALUE);
    Debug("\n$VARIABLE  TEXT '$VALUE'");
}  

sub EndTag
{
    my ( $v1, $v2 ) = @_;
    if( $v2 eq 'VALUE'  )
    {
        #Debug("  VARIABLE '$VARIABLE' VALUE '$VALUE'\n");
	if( defined $TABLE )
	{
		if( defined $LINE && defined $VARIABLE )
		{
			push @{$REQUEST->{$TABLE}->{$LINE}->{$VARIABLE}} , $VALUE;
			$SHREQUEST .= $TABLE.'_'.$LINE.'_'.$VARIABLE.' '.$VALUE."\n";
		}
	}
	elsif( defined $LINE )
	{
		push @{$REQUEST->{$LINE}->{$VARIABLE}} , $VALUE;
		$SHREQUEST .= $LINE.'_'.$VARIABLE.' '.$VALUE."\n";
	}
	else
	{
        	push @{$REQUEST->{$VARIABLE}} , $VALUE;
		$SHREQUEST .= "$VARIABLE $VALUE\n";
	}
	$VALUE = undef;
    }
    elsif( defined $VARIABLE )
    {
        #Debug("  VARIABLE '$VARIABLE' VALUE '$VALUE'\n");
	if( defined $TABLE )
	{
		if( defined $LINE && defined $VARIABLE )
		{
			if( defined $VARIABLES->{$APPLICATION}->{$VARIABLE}->[1] &&  $VARIABLES->{$APPLICATION}->{$VARIABLE}->[1] eq 'text' )
			{
				$REQUEST->{$TABLE}->{$LINE}->{$VARIABLE} = "$VALUE" if ( ! defined $REQUEST->{$TABLE}->{$LINE}->{$VARIABLE} );
				$VALUE = encode_base64($VARIABLE,'');
				$SHREQUEST .= $TABLE.'_'.$LINE.'_'.$VARIABLE.' '.$VALUE."\n";
			}
			elsif( defined $VARIABLES->{$APPLICATION}->{$VARIABLE}->[1] && $VARIABLES->{$APPLICATION}->{$VARIABLE}->[1] eq 'filefield' )
			{
				$REQUEST->{$TABLE}->{$LINE}->{$VARIABLE}->{'content'}    = $VALUE;
				$REQUEST->{$TABLE}->{$LINE}->{$VARIABLE}->{'filename'} = $ATTRIBUTES{'filename'};
				$SHREQUEST .= $TABLE.'_'.$LINE.'_'."$VARIABLE content $VALUE\n";
				$SHREQUEST .= $TABLE.'_'.$LINE.'_'."$VARIABLE filename ".$ATTRIBUTES{'filename'}."\n";
			}
			else
			{
				$REQUEST->{$TABLE}->{$LINE}->{$VARIABLE} = "$VALUE"  if ( ! defined $REQUEST->{$TABLE}->{$LINE}->{$VARIABLE} );
				$SHREQUEST .= $TABLE.'_'.$LINE.'_'."$VARIABLE $VALUE\n";
			}
		}
	}
	elsif( defined $LINE )
	{
		if( defined $VARIABLES->{$APPLICATION}->{$VARIABLE}->[1] &&  $VARIABLES->{$APPLICATION}->{$VARIABLE}->[1] eq 'text' )
		{
			$REQUEST->{$LINE}->{$VARIABLE} = "$VALUE" if ( ! defined $REQUEST->{$LINE}->{$VARIABLE} );
			$VALUE = encode_base64($VARIABLE,'');
			$SHREQUEST .= $LINE.'_'."$VARIABLE $VALUE\n";
		}
		elsif( defined $VARIABLES->{$APPLICATION}->{$VARIABLE}->[1] && $VARIABLES->{$APPLICATION}->{$VARIABLE}->[1] eq 'filefield' )
		{
			$REQUEST->{$LINE}->{$VARIABLE}->{'content'}    = $VALUE;
			$REQUEST->{$LINE}->{$VARIABLE}->{'filename'} = $ATTRIBUTES{'filename'};
			$SHREQUEST .= $LINE.'_'."$VARIABLE content $VALUE\n";
			$SHREQUEST .= $LINE.'_'."$VARIABLE filename ".$ATTRIBUTES{'filename'}."\n";
		}
		else
		{
        		$REQUEST->{$LINE}->{$VARIABLE} = "$VALUE"  if ( ! defined $REQUEST->{$LINE}->{$VARIABLE} );
			$SHREQUEST .= $LINE.'_'."$VARIABLE $VALUE\n";
		}
	}
	else
	{
		if( defined $VARIABLES->{$APPLICATION}->{$VARIABLE}->[1] &&  $VARIABLES->{$APPLICATION}->{$VARIABLE}->[1] eq 'text' )
		{
			$REQUEST->{$VARIABLE} = "$VALUE" if ( ! defined $REQUEST->{$VARIABLE} );
			$VALUE = encode_base64($VARIABLE,'');
			$SHREQUEST .= "$VARIABLE $VALUE\n";
		}
		elsif( defined $VARIABLES->{$APPLICATION}->{$VARIABLE}->[1] && $VARIABLES->{$APPLICATION}->{$VARIABLE}->[1] eq 'filefield' )
		{
			$REQUEST->{$VARIABLE}->{'content'}    = $VALUE;
			$REQUEST->{$VARIABLE}->{'filename'} = $ATTRIBUTES{'filename'};
			$SHREQUEST .= "$VARIABLE content $VALUE\n";
			$SHREQUEST .= "$VARIABLE filename ".$ATTRIBUTES{'filename'}."\n";
		}
		else
		{
        		$REQUEST->{$VARIABLE} = "$VALUE"  if ( ! defined $REQUEST->{$VARIABLE} );
			$SHREQUEST .= "$VARIABLE $VALUE\n";
		}
	}
	$VARIABLE = $VALUE = $TABLE = $LINE = undef;
    }
    else
    {
	$LANG = GetSessionValue('lang');
	if( $APPLICATION eq 'OSS_BASE' )
	{
	    $xreply = call_oss_base();
	}
	elsif( $APPLICATION eq 'LMD' )
	{
	   $xreply =  call_lmd();
	}
	elsif( $ACTION eq 'login' )
	{
	   $xreply =  login();
	}
	elsif( $ACTION eq 'getMenu' )
	{
	   my $role = GetSessionValue('role');
	   #Debug("Role $role");
	   $xreply =  GetMenu($role); 
	}
	elsif( -e '/var/adm/oss/oss_service' )
	{
	    my $lf = `cat /var/adm/oss/oss_service`; chomp $lf;
	    $xreply = oss_service($lf);
	}
	elsif( -e '/var/adm/oss/must-restart' )
	{
	    my $role = GetSessionValue('role');
	    if( $role =~ /sysadmins/ )
	    {
		if( $ACTION eq 'reboot' )
		{
		     system('/sbin/reboot');
		     RequestError(8);
		}
		else
		{
	    	     $xreply = oss_service('/var/adm/oss/must-restart');
		}	     
	    }
	}
	else
	{
	    $ACTION = 'default' if( $ACTION eq 'cancel' );

	    print "Now we start executing \n".Dumper($REQUEST) if $DEBUG;
	    print "Now we start executing \n".$SHREQUEST if $DEBUG;
	    if( ! defined $INTERFACE->{$APPLICATION} )
	    {
	        RequestError('2');
	    }
	    elsif( ! defined $INTERFACE->{$APPLICATION}->{$ACTION} )
	    {
	        RequestError('3');
	    }
	    #Save the request if neccesary;
	    archive_request() if( $ARCHIVE_REQUESTS );
	    my $reply = undef;
	    if( $INTERFACE->{$APPLICATION}->{$ACTION} eq 'perl' )
	    {
		# Now we execute the requested action
		my $connect = { SESSIONID    => $SESSIONID, 
		    	    aDN	         => GetSessionValue('dn'),
	 	    	    sDN	         => GetSessionValue('sdn'),
		    	    aPW          => GetSessionValue('userpassword'),
		    	    DBH          => $DBH,
			    PRINTSERVER_LOCAL => $PRINTSERVER_LOCAL,
			    MAILSERVER_LOCAL  => $MAILSERVER_LOCAL,
			    PROXYSERVER_LOCAL => $PROXYSERVER_LOCAL
		    	  };
		require "$APPLICATION.pm";
		my $obj   = undef; eval { $obj = $APPLICATION->new($connect); };
		if( ! defined $obj )
		{
		    ReturnError(['CAN_NOT_CREATE_OBJECT',__('Can not create the object: ','GLOBAL')."$APPLICATION"]);
		}
		$reply = $obj->$ACTION($REQUEST);
		#eval { $reply = $obj->$ACTION($REQUEST); };
		if( ! $reply )
		{
		    ReturnError(['CAN_NOT_EXECUTE_ACTION',__('Can not execute the action: ','GLOBAL')."$APPLICATION".'->'."$ACTION"]);
		}
		$obj->destroy;
	    }
	    else
	    {
		$SHREQUEST .= 'ip '.GetSessionValue('ip')."\n";
		$SHREQUEST .= 'aDN '.GetSessionValue('dn')."\n";
		$SHREQUEST .= 'sDN '.GetSessionValue('sdn')."\n";
		$SHREQUEST .= 'aPW '.GetSessionValue('userpassword')."\n";
		$SHREQUEST .= "PRINTSERVER_LOCAL $PRINTSERVER_LOCAL\n";
		$SHREQUEST .= "MAILSERVER_LOCAL $MAILSERVER_LOCAL\n";
		$SHREQUEST .= "PROXYSERVER_LOCAL $PROXYSERVER_LOCAL\n";
	    	my $tmp = cmd_pipe( "$INTERFACE->{$APPLICATION}->{$ACTION} $ACTION", $SHREQUEST);
 	        print "tmp:".Dumper($tmp) if $DEBUG;
		$reply = ConvertPlainToReplay($tmp);
	    }
 	    print "reply:".Dumper($reply) if $DEBUG;
	    if( ref $reply eq 'HASH')
	    { #Error or notice replay
	        $xreply = HASHtoXML($reply);
	    }
	    else
	    {
	        $xreply = ARRAYtoXML($reply);
	    }
	}
	Reply();
    }
}
#########################################
# END Soubrutines for the xml parsing #
#########################################

sub ConvertPlainToReplay
{
    my $x     = shift;
    my @r     = ();
    my $v     = undef; # Value list
    my $d     = undef; # Default list
    my $l     = undef;
    my $t     = undef;
    my $name  = undef;
    my $value = undef;
    my $label = undef;
    my $line  = undef;
    my $table = undef;
    $x .= "\n########END########";

    foreach my $i ( split /\n/, $x )
    {
        my ( $n, $val ) = split /\s+/, $i, 2;
	if( $name && ( $n ne $name || $name eq 'label') ) 
	{ # This is a new variable
	    if( $value )
	    {
	    	if( defined $l )
		{
	        	$l .= ", { '$name' => '$value' }";
		}
		else
		{
	        	push @r , { $name => $value };
		}
		$value = undef;
	    }
	    else
	    {
		my $k = '';
		$d =~ s/,$//;
	        $k = "[ $v '---DEFAULTS---' , $d ]";
	    	if( defined $l )
		{
	        	$l .= ", { $name =>  $k }";
		}
		else
		{
	        	push @r , { $name => eval $k };
		}
		$v = $d = undef;
	    }
	}
	last if( $i =~ /########END########/ );
	$name = $n;
	if( $name eq 'TABLE' )
	{
	    $t = "'$val'";
	    $name = undef;
	    next;
	}
	if( $name eq 'LINE' )
	{
	    $l = "'$val'";
	    $name = undef;
	    next;
	}
	if( $name eq 'ENDTABLE' )
	{
	    push @r , { 'table' => eval "[ $t ]" } ;
	    $name = $t = undef;
	    next;
	}
	if( $name eq 'ENDLINE' )
	{
	    if( defined $t )
	    {
	    	$t .= ", { 'line' => [ $l ]  }" ;
	    }
	    else
	    {
	    	push @r , { line => eval "[ $l ]" };
	    }
	    $l = $name = undef;
	    next;
	}
	if( $val =~ s/^#BASE64#// )
	{
	    $value =  decode_base64($val);
	}
	elsif( $val =~ s/^#LABEL#// )
	{
	    $label = $val;
	}
	elsif( $val =~ s/^#VALUE#// )
	{
	    $v .=  "[ '$val' , '$label' ],";
	    $label = undef;
	}
	elsif( $val =~ s/^#DEFAULT#// )
	{
	    $d .= "'$val',";
	}
	else
	{
	    if( $VARIABLES->{$APPLICATION}->{$name}->[1] =~ /^popup|list$/ )
	    {
	        $v .= "'$val',";
	    }
	    else
	    {
	        $value = $val;
	    }
	}
    }
    return \@r;
}

sub Reply
{
   #my  $octets       = encode("utf8",$xreply);
   # TODO It have to work as utf8 too.
   # my  $octets       = encode("iso-8859-1",$xreply);
   # my  $octets       = $xreply;
   $xreply = decode("utf8", $xreply);
   $xreply = encode("utf8", $xreply);
   Debug($xreply."\n");
   my  $package_size = length($xreply);
   my  $ps           = pack("l", $package_size);
   syswrite $CLIENT, $ps, 4;
   my $offset = 0; 
   my $bytes  = 0;
   while( $offset < $package_size )
   {
	$bytes = syswrite $CLIENT, $xreply, 16834, $offset;
	$offset += $bytes;
   }
   my $c = syswrite $CLIENT, $xreply,  length $xreply;
   $APPLICATION = $ACTION = undef;
}

sub ReturnError
{
    my $error  = shift;
    my ( $code, $mess ) = @{$error};
    my $output;
    my $writer = new XML::Writer(OUTPUT => \$output, ENCODING => "UTF-8", DATA_MODE => 1);
    $writer->xmlDecl("UTF-8");
    $writer->startTag("reply", name=>$APPLICATION, action=>$ACTION, sessionID=>$SESSIONID, result=> "4" );
        $writer->dataElement("ERROR",$code);
        $writer->dataElement("ERROR",$mess);
    $writer->endTag("reply");
    $writer->end();
    return $output;
}

sub RequestError
{
    my $error = shift;
    my $RequestErrors = 
    {
    	1 => [ 'NO_REQUEST_NAME' ,       __('The request has no name.','GLOBAL')],
    	2 => [ 'BAD_APPLICATION' ,       __('The requested application does not exist.','GLOBAL')],
    	3 => [ 'BAD_ACTION' ,            __('The requested action (request name) does not exist.','GLOBAL')],
    	4 => [ 'NO_SESSION' ,            __('The requested session does not exist.','GLOBAL')],
    	5 => [ 'SESSION_TIMEOUT' ,       __('The requested session is out of time.','GLOBAL')],
    	6 => [ 'NO_RIGHT_TO_SESSION' ,   __('You do not have rights to access this session.','GLOBAL')],
    	7 => [ 'NO_RIGHT_TO_APLICATION' ,__('You do not have rights to access this aplication.','GLOBAL')],
    	8 => [ 'REBOOT',                 __('The server will be rebooted.','GLOBAL')]
    };
    $xreply = ReturnError($RequestErrors->{$error});
    Reply();
    close $CLIENT;
    $DBH->disconnect;
    exit 1;
}

sub GetMenu
{
    my $role  = shift;
    my $output;
    my $writer = new XML::Writer(OUTPUT => \$output, ENCODING => "UTF-8", DATA_MODE => 1);
    $writer->startTag("reply", name=>"getMenu", sessionID=>$SESSIONID, role=>"$role", result=> "0" );
    foreach my $category ( @CATEGORIES )
    {
	next if ( ! defined $MENU->{$role}->{$category} );
    	$writer->startTag("category", name => $category, label => __($category,'GetMenu') );
	my @apps = sort { $MENU->{$role}->{$category}->{$a}->{order} <=> $MENU->{$role}->{$category}->{$b}->{order} } keys %{$MENU->{$role}->{$category}};
	foreach my $app ( @apps )
	{
		#$writer->dataElement('application',$app, label => __($app,'GetMenu'), order => $MENU->{$role}->{$category}->{$app}->{order} );
		$writer->dataElement('application',$app, label => __($app,'GetMenu'));
		next;
		if( defined $MENU->{$role}->{$category}->{$app}->{description} )
		{
		    $writer->dataElement('description',__($MENU->{$role}->{$category}->{$app}->{description},$app));
		}
		else
		{
		    $writer->dataElement('description',__($MENU->{$role}->{$category}->{$app}->{title},$app));
		}
		if( defined $MENU->{$role}->{$category}->{$app}->{help} )
		{
		    $writer->startTag("help");
		    $writer->cdata($MENU->{$role}->{$category}->{$app}->{help});
		    $writer->endTag("help");
		}
	}
	$writer->endTag("category");
    }
    $writer->endTag("reply");
    $writer->end();
    return $output;
}

sub HASHtoXML
{
    my $Hash   = shift;
    my $output;
    my $writer = new XML::Writer(OUTPUT => \$output, ENCODING => "UTF-8", DATA_MODE => 1);
    my $result = 0;
    my $TYPE   = $Hash->{TYPE};
    delete $Hash->{TYPE};

    if( $TYPE eq 'ERROR' )
    {
        $result = 8;
    }
    $writer->xmlDecl("UTF-8");
    $writer->startTag("reply", name=>$APPLICATION, action=>$ACTION, sessionID=>$SESSIONID, result=>$result );
    if( defined $CAPABILITIES->{$APPLICATION}->{title} )
    {
	$writer->dataElement('title',__($CAPABILITIES->{$APPLICATION}->{title}->[0]));
    }
    foreach my $key ( sort keys %{$Hash} )
    {
	if( $key =~ /NOTRANSLATE/i )
	{
		$writer->dataElement($TYPE, $Hash->{$key});
	}
	else
	{
		$writer->dataElement($TYPE, __($Hash->{$key}));
	}
    }
    $writer->endTag("reply");
    $writer->end();
    return $output;
}

sub ARRAYtoXML
{
    my $Array = shift;
    my $output;
    my $writer = new XML::Writer(OUTPUT => \$output, ENCODING => "UTF-8", DATA_MODE => 1, UNSAFE=>1);
    $writer->xmlDecl("UTF-8");
    $writer->startTag("reply", name=>$APPLICATION, action=>$ACTION, sessionID=>$SESSIONID, result=> "0" );
    if( defined $CAPABILITIES->{$APPLICATION}->{title} )
    {
	$writer->dataElement('title',__($CAPABILITIES->{$APPLICATION}->{title}->[0]));
    }

    foreach my $line ( @{$Array} )
    {
    	my $Tag = (keys(%{$line}))[0];
	if( ref $line->{$Tag} eq 'ARRAY' )
	{
	    if( $Tag eq 'variable' )
	    { #Handling of getCapabilities
		my $name       = shift @{$line->{$Tag}};
		my @attributes = @{$VARIABLES->{$APPLICATION}->{$name}};
		print "5".Dumper @attributes if $DEBUG;
		$writer->dataElement($Tag,$name, @attributes);
	    }
	    elsif( $Tag eq 'table' )
	    {
	        my @lines  = @{$line->{$Tag}};
		my $name   = shift @lines;
		$writer->startTag('table', name=>$name );
		writeHead($writer,$lines[0]);
		shift @lines if( defined $lines[0]->{head} );
		foreach my $line ( @lines )
		{
	            writeLine($writer,$line->{'line'} );
		}
    		$writer->endTag('table');
	    }
	    elsif( $Tag eq 'line' )
	    {
	        writeLine($writer,$line->{$Tag});
	    }
	    else
	    {
	    	writeVariable($writer,$Tag,$line);
	    }	
	}
	else
	{
	    writeVariable($writer,$Tag,$line);
	}

    }
    $writer->endTag("reply");
    $writer->end();
    return $output;
}

sub writeHead
{
    my $writer = shift;
    my $line   = shift;
    $writer->startTag('headLine');
    if( defined $line->{head} )
    {
	foreach my $hash (@{$line->{head}}) 
	{
	    if( ref $hash eq 'HASH')
	    {
	    	$writer->dataElement('head',$hash->{name}, @{$hash->{attributes}});
	    }
	    else
	    {
	    	$writer->dataElement('head',$hash, label => __($hash));
	    }
	}
    }
    else
    {
	foreach my $hash (@{$line->{line}}) 
	{
            next if( ref $hash ne 'HASH');
	    my $name  = (keys(%{$hash}))[0];
	    if( defined $hash->{attributes} )
    	    {
        	$name  = $hash->{name};
	    }
	    $writer->dataElement('head',$name, label => __($name));
	}
    }
    $writer->endTag('headLine');
}

sub writeLine
{
    my $writer = shift;
    my $line   = shift;
    my $name   = shift @{$line};
    $writer->startTag('line', name=>$name);
    foreach my $hash (@{$line}) 
    {
        my $name  = (keys(%{$hash}))[0];
        writeVariable($writer,$name,$hash);
    }
    $writer->endTag('line');
}

sub writeVariable
{
    my $writer = shift;
    my $name   = shift;
    my $hash   = shift;
    my $type   = 'string';

    print "writeVariable ".Dumper($hash) if $DEBUG;
    my @attributes = ();
    my $value      = $hash->{$name};
    my $notrans= ( $name =~ s/^notranslate_// );
    if( defined $hash->{attributes} )
    {
	$name  = $hash->{name};
	$value = $hash->{value};
    	push @attributes, @{$hash->{attributes}};
    }
    elsif( defined $VARIABLES->{$APPLICATION}->{$name})
    {
        push @attributes, @{$VARIABLES->{$APPLICATION}->{$name}};
    }
    if( $name !~ /^action|rightaction|label$/ && ! scalar @attributes )
    { #This is a simple string variable
          @attributes = ( 'type' , 'string' );
    }
    $type = $attributes[1] || '';
    # First we try to translate the tag in label attribute if we must
    if( ! $notrans && $name ne 'label' && $name ne 'subtitle')
    {
	if ( $name =~ /^action|rightaction$/ || $type eq 'checkbox' )
	{
	    translate($value,\@attributes);
	}
	else
	{
	    translate($name,\@attributes);
	}
    }
    $attributes[1] =~ s/translated// if($attributes[1]);
    $writer->startTag($name, @attributes);

    if( $type eq "text" )
    {
        $writer->cdata($value);
    }
    elsif( $type =~ /(list|popup)$/  )
    {
	my $default = 0;
	foreach my $v (@{$value})
	{
	    my $val    = $v;
	    my $label  = $v;
	    my @attrs  = ();
	    if( 'ARRAY' eq ref $v )
	    {
	        $val    = shift @{$v};
	        $label  = shift @{$v};
	        @attrs  =  @{$v};
	    }
	    if( $val eq '---DEFAULTS---' )
	    {
	        $default = 1;
		next;
	    }
	    if( $default )
	    {
	    	$writer->dataElement('DEFAULT',$val);
	    }
	    else
	    {
		if($type =~ /^translated*/)
		{
			push @attrs,  ( 'label' => __($label) );
		}
		else
		{
			push @attrs,  ( 'label' => $label );
		}
    		$writer->dataElement('VALUE', "$val", @attrs );
	    }
	}
	$type =~ s/translated//;
    }
    elsif( $type eq 'filetree' )
    {
	$writer->raw($value);	
    }
    elsif( !$notrans && ($name eq 'label' || $name eq 'subtitle') )
    {
        $writer->characters(__($value));
    }
    else
    {
        $writer->characters($value);
    }
    $writer->endTag($name);

}

sub __
{
    my $string  = shift;
    my $section = shift || $APPLICATION;
    my $lang    = shift || $LANG;
    $string     =~ s/'/\\'/g;
    my $lstring = lc($string);
    $section = 'DEFAULT' if ( ! defined $section );

    my $sel  = $DBH->prepare("SELECT value FROM missedlang WHERE lang='$lang' AND section='$section' AND ( string='$string' OR string='$lstring' )");
    $sel->execute;
    my $missedvalue = $sel->fetch();
    if( defined $missedvalue )
    {
        if( $missedvalue->[0] ne '' )
	{
	    return $missedvalue->[0];
	}
    }

    $sel  = $DBH->prepare("SELECT value FROM lang WHERE lang='$lang' AND section='$section' AND ( string='$string' OR string='$lstring' )");
    $sel->execute;
    my $value = $sel->fetch();
    if( defined $value )
    {
        return $value->[0];
    }
    
    $sel  = $DBH->prepare("SELECT value FROM lang WHERE lang='$lang' AND section='GLOBAL' AND ( string='$string' OR string='$lstring' )");
    $sel->execute;
    $value = $sel->fetch();
    if( defined $value )
    {
        return $value->[0];
    }

    #This was never translated. We put it into miessed lang with empty value
    if( ! defined $missedvalue )
    {
#	$string = decode("utf8", "$string");
        $string =~ s/'/\\'/g;
       	$DBH->do("INSERT INTO missedlang VALUES ('$lang','$section','$string','')");
    }
    if( $lang eq 'EN' )
    {
        return $string;
    }
    # Probably there is an english "translation"
    $sel  = $DBH->prepare("SELECT value FROM lang WHERE lang='EN' AND section='$section' AND ( string='$string' OR string='$lstring' )");
    $sel->execute;
    $value = $sel->fetch();
    if( defined $value )
    {
        return $value->[0];
    }
    
    $sel  = $DBH->prepare("SELECT value FROM lang WHERE lang='EN' AND section='GLOBAL' AND ( string='$string' OR string='$lstring' )");
    $sel->execute;
    $value = $sel->fetch();
    if( defined $value )
    {
        return $value->[0];
    }
    return $string;
}

sub translate($$) 
{
    my $name    = shift;
    my $attrs   = shift;
    my $labeled = 0; 
    my $li      = 0; 
    my $helped  = 0; 
    my $hi      = 0; 
    my $backed  = 0; 
    my $bi      = 0; 
    my $av      = 1;
    my $i       = 0;
    foreach my $attr ( @{$attrs} )
    {
       $i++;
       if ( $av && $attr eq "label")
       {
          $labeled = 1;
	  $li = $i;
       }
       if ( $av && $attr eq "help")
       {
          $helped = 1;
	  $hi = $i;
       }
       if ( $av && $attr eq "backlabel")
       {
          $backed = 1;
	  $bi = $i;
       }
       $av = 1 - $av;
    }
    if( $labeled )
    {
       $attrs->[$li] = __($attrs->[$li]);
    }
    else
    {
       push @{$attrs}, ( 'label' ,  __($name) );
    }
    if( $helped )
    {
       $attrs->[$hi] = __($attrs->[$hi]);
    }
    if( $backed )
    {
       $attrs->[$bi] = __($attrs->[$bi]);
    }
}

sub login
{
    my $oss    = oss_base->new();
    my $dn     = '';
    my $result = undef;
    my $sdn    = $REQUEST->{sDN} || '';
    if( defined $REQUEST->{sDN} )
    {
        $dn = $oss->get_user_dn($REQUEST->{username},$REQUEST->{sDN});
    }
    else
    {
        $dn  = $oss->get_user_dn($REQUEST->{username});
        $sdn = $oss->get_school_base($dn);
    }
    if( !$REQUEST->{ip} || $REQUEST->{ip} eq $oss->get_school_config('SCHOOL_PROXY') || $REQUEST->{ip} eq $oss->get_school_config('SCHOOL_SERVER') )
    {
	    $REQUEST->{ip} = $oss->get_config_value($dn,'LOGGED_ON') || 'localhost';
    }
    if( $result = $oss->login($dn,$REQUEST->{userpassword},$REQUEST->{ip},0) )
    {
	my $now  = time;
	my $rand = rand((time)*$$);
	my @reply= ();
	$SESSIONID   = md5_hex($rand.$result);
	my $role = $result->{$dn}->{role}->[0] || 'students';
	$role = $ROLEMAP{$role} if (defined $ROLEMAP{$role} );
	$LANG = $result->{$dn}->{preferredlanguage}->[0] || 'EN';
	if( $LANG =~ /(.*)_(.*)/){ $LANG = uc($1) };
	$LANG = uc($LANG);
	my $cn   = $result->{$dn}->{cn}->[0] || $result->{$dn}->{uid}->[0];
	my $room = $oss->get_room_name(get_parent_dn($oss->get_workstation($REQUEST->{ip}))) || '';
	$room = '' if( $room =~ /SERVER_NET|ANON_DHCP/ );
	#TODO REMOVE IT THIS IS TEST ONLY
	#$room = 'testroom' if ( ! $room &&  $role =~ /sysadmins/ );
	########
	$REQUEST->{userpassword} = encode_base64($RSA_PUBLIC->encrypt($REQUEST->{userpassword}));
	$DBH->do("INSERT INTO sessions VALUES ('$SESSIONID','$dn','$sdn','".$REQUEST->{username}."','".$REQUEST->{userpassword}."','$role','".$REQUEST->{ip}."','$room',$now,0,$now,'$LANG',NULL)");
	$APPLICATION=$ACTION="login";
	#Now we search for the default application
	my @app = ('Settings','changePassword','default');
	if( $role =~ /sysadmins/ )
	{
		@app = ('System','SystemOverview','default');
	}
        elsif( $role eq 'teachers' )
        {
		@app = ('Students','ClassRoomOverview','default');
        }
	my $vap  = $oss->get_vendor_object($dn,'oss','defaultApplication');
	if( defined $vap->[0] ) 
	{
		@app = split /,/,$vap->[0];
	}
	else
	{
		$vap = $oss->get_vendor_object($oss->get_primary_group_of_user($dn),'oss','defaultApplication');
		if( defined $vap->[0] )
		{
			@app = split /,/,$vap->[0];
		}
	}
	push @reply, { cn   => "$cn" }; 
	push @reply, { role => "$role" }; 
	push @reply, { room => "$room" }; 
	push @reply, { lang => "$LANG" }; 
	push @reply, { name => 'logout', value => __("Logout","LOGIN","$LANG"), attributes => [ type => 'label'] };
	push @reply, { name=>'defaultApplication', value=>$app[1], attributes => [ CATEGORY=>$app[0] , action=>$app[2]] }; 
	$oss->destroy();
	return ARRAYtoXML(\@reply);
    }
    else
    {
	$oss->destroy();
        return ReturnError(['LOGIN_FAILED',$oss->{ERROR}->{text}]);
    }
}

sub call_lmd
{
    my @attrs = ();
    foreach ( sort keys %$REQUEST )
    {
    	push @attrs, $REQUEST->{$_};
    }
    my $result = '';
    if( $ACTION eq 'AddSessionDatas' )
    {
    	$result = AddSessionDatas(@attrs);
    }
    elsif( $ACTION eq 'GetSessionDatas' )
    {
    	$result = GetSessionDatas(@attrs);
    }
    elsif( $ACTION eq 'DeleteSessionDatas' )
    {
    	$result = DeleteSessionDatas(@attrs);
    }
    elsif( $ACTION eq 'GetSessionValue' )
    {
    	$result = GetSessionValue(@attrs);
    }
    elsif( $ACTION eq 'UpdateSessionTime' )
    {
    	$result = GetSessionValue('lastaction');
    }
    elsif( $ACTION eq 'trans' )
    {
    	$result = trans(@attrs);
    }
    my $output;
    my $writer = new XML::Writer(OUTPUT => \$output, ENCODING => "UTF-8", DATA_MODE => 1, UNSAFE=>1);
    $writer->xmlDecl("UTF-8");
    $writer->startTag("reply", name=>$APPLICATION, action=>$ACTION, sessionID=>$SESSIONID, result=> "0" );
    $writer->dataElement('value',$result);
    $writer->endTag("reply");
    $writer->end();
    return $output;

}

sub call_oss_base
{
    my $connect = { aDN => 'anon' };
    if( defined $SESSIONID )
    {
	$connect = { SESSIONID    => $SESSIONID, 
	 	    aDN	         => GetSessionValue('dn'),
	 	    sDN	         => GetSessionValue('sdn'),
	 	    aPW          => GetSessionValue('userpassword'),
	 	    DBH          => $DBH
	 	  };
    }
    my $oss   = oss_base->new($connect);
    my @attrs = ();
    foreach ( sort keys %$REQUEST )
    {
    	push @attrs, $REQUEST->{$_};
    }
    my $result = $oss->$ACTION(@attrs);
    my $output;
    my $writer = new XML::Writer(OUTPUT => \$output, ENCODING => "UTF-8", DATA_MODE => 1, UNSAFE=>1);
    $writer->xmlDecl("UTF-8");
    $writer->startTag("reply", name=>$APPLICATION, action=>$ACTION, sessionID=>$SESSIONID, result=> "0" );
    if( ref $result eq 'HASH' )
    {
    	foreach my $dn ( keys %$result )
	{
	    $writer->dataElement('STARTLINE',$dn);
	    if( ref $result->{$dn} eq 'ARRAY' )
	    {
	    	foreach my $v ( @{$result->{$dn}} )
	        {
	    	    $writer->dataElement('value',$dn);
	        }
	    }
	    if( ref $result->{$dn} eq 'HASH' )
	    {
	    	foreach my $k ( %{$result->{$dn}} )
	        {
		    if( ref $result->{$dn}->{$k} eq 'ARRAY' )
		    {
		    	foreach my $v ( @{$result->{$dn}->{$k}} )
			{
	    	    	    $writer->dataElement($k,$v);
			}
		    }
		    elsif( ref $result->{$dn}->{$k} eq 'SCALAR' )
		    {
	    	    	$writer->dataElement($k,$result->{$dn}->{$k});
		    }
	        }
	    }
	    $writer->dataElement('ENDLINE',$dn);
	}
    }
    elsif( ref $result eq 'ARRAY' )
    {
	$writer->startTag($ACTION, type => 'popup', label => __($ACTION,'OSS_BASE') );
    	foreach my $v ( @$result )
	{
	    if( ref $v eq 'HASH' )
	    {
		my $k = (keys(%$v))[0];
		$writer->dataElement('value',$k, label => $v->{$k} )
	    }
	    else
	    {
		$writer->dataElement('value',$v);
	    }
	}
	$writer->endTag($ACTION);
    }
    else
    {
    	$writer->dataElement('value',$result);
    }

    if( $ACTION eq 'get_schools'){
	my $lang =  uc(substr($oss->get_school_config("SCHOOL_LANGUAGE"),0,2));
	$writer->dataElement('login', __("Login","LOGIN","$lang"));
	$writer->dataElement('password', __("Password","LOGIN","$lang"));
	$writer->dataElement('login_action', __("Login Action","LOGIN","$lang"));
	$writer->dataElement('login_error', __("Cannot login. Please, type in a valid login and password.","LOGIN","$lang"));
	$writer->dataElement('choose_school', __("Please, choose a school to login:","LOGIN","$lang"));
    }

    $writer->endTag("reply");
    $writer->end();
    return $output;
}

sub check_rights
{
	return 1 if !defined $APPLICATION;
	#TODO Make next rights more flexible
	return 1 if $CAPABILITIES->{$APPLICATION}->{allowedRole}->[0] eq 'all';
	return 1 if contains(GetSessionValue('role'),$CAPABILITIES->{$APPLICATION}->{allowedRole});
	return 0;
}

sub Debug
{
    if( $DEBUG )
    {
	print shift;
    }
}

sub usage
{
    print $@." [<options>]\n";
    print "Options:\n";
    print "  --help                 Print this help message\n";
    print "  --debug                Run in debug mode, no daemonize.\n";
    print "  --init                 Initialize the lmd daemon.\n";
    print "  --port=<PORT>     	    The port on them the daemon is listening.\n";
    print "  --address=<ADDRESS>    The adress on them the daemon is listening.\n";
    print "  --stime=<STIME in min> The default session time.\n";
    print "  --disabled=<Templates,RootPassword> Comma separated list of disabled modules.\n";
}

sub archive_request()
{
    my $tmp = $APPLICATION.":".$ACTION;
    return if( $tmp =~ /$APPS_NOT_TO_ARCHIVE/ );
    return if( $tmp !~ /$APPS_TO_ARCHIVE/ );
    $DBH->do("INSERT history  VALUES ('".time."','".GetSessionValue('username')."','".GetSessionValue('room')."','$APPLICATION','$ACTION','".encode_base64(freeze($REQUEST),'')."')");
}

sub daemonize
{
    if ( ! $DEBUG )
    {
        open STDIN,"/dev/null";
        open STDOUT,">>$LOGDIR"."/lmd.log";
        open STDERR,">>$LOGDIR"."/lmd.err";
        chdir "/";
        fork && exit 0;
        print STDERR "\n\n----------------------------------------\n";
        print STDERR xml_time();
        print "\n\n----------------------------------------\n";
        print xml_time();
        print time,": LMD successfully forked into background and running on PID ",$$,"\n";
    }
    else
    {
        print time,": LMD running in debug-mode on PID ",$$,"\n";
    }
    open FILE,">$PIDFILE";
    print FILE $$;
    close FILE;
}

sub sort_by_lang
{
    my $l    = shift;
    my @ol   = ();
    my %hash = ();
    foreach my $t ( @{$l} )
    {
	chomp $t;
    	$hash{__($t)} = $t;
    }
    foreach my $t ( sort keys %hash)
    {
    	push @ol, $hash{$t};
    }
    return @ol;
}

sub oss_service
{
    my $logfile = shift;
    my $value=`cat $logfile`;
    my $output;
    my $writer = new XML::Writer(OUTPUT => \$output, ENCODING => "UTF-8", DATA_MODE => 1, UNSAFE=>1);
    $writer->xmlDecl("UTF-8");
    $writer->startTag("reply", name=>'Service', action=>'Message', sessionID=>$SESSIONID, result=> "0" );
    my @attributes = ( 'type' , 'label' );
    $writer->startTag('label', @attributes);
    $writer->cdata('Your server is in service state');
    $writer->endTag('label');
    @attributes = ( 'type' , 'text' );
    $writer->startTag('message', @attributes);
    $writer->cdata($value);
    $writer->endTag('message');
    if( $logfile eq '/var/adm/oss/must-restart' )
    {
        writeVariable($writer,'action',{ action => 'reboot' });
    }
    $writer->endTag("reply");
    $writer->end();
    return $output;

}
