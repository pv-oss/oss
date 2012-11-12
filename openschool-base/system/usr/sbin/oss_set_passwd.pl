#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2005 Peter Varkoly Fuerth, Germany.  All rights reserved.
#
# $Id: oss_set_passwd.pl,v 1.6 2007/02/09 17:58:12 pv Exp $
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use Getopt::Long;
use oss_base;
use oss_utils;

# Global variable
my $connect    = {};
my $line       = "";
my $oid        = "";
my $dn         = "";
my $uid        = "";
my $userpassword   = "";
my $sso        = 0;
my $mustchange = 0;
my $pwmech     = 'SMD5';
binmode STDIN, ':utf8';

if( ! defined @ARGV || $ARGV[0] eq '-' )
{
	while(<STDIN>)
	{
	  $line .= $_;
	  # Clean up the line!
	  chomp; s/^\s+//; s/\s+$//;

	  my ( $key, $value ) = split / /,$_,2;

          next if( getConnect($connect,$key,$value));

	  if( $key eq 'uid' )
	  {
		$uid = $value;
	  }
	  elsif ( $key eq 'oid' )
	  {
		$oid = $value;
	  }
	  elsif ( $key eq 'userpassword' )
	  {
		$userpassword = $value;
	  }
	  elsif ( $key eq 'mustchange' )
	  {
		$mustchange = 1;
	  }
	  elsif ( $key eq 'sso' )
	  {
		$sso = 1;
	  }
	  elsif ( $key eq 'pwmech' )
	  {
		$pwmech = $value;
	  }
	  elsif( !defined $value  || $value eq  '' )
          {
          	if( $key =~ /^uid=.*/i)
          	{
			$dn =  $key;
		}
          }

	}
}
else
{
	# Parsing the attributes
	my %options    = ();
	my $result = GetOptions(\%options,
	                      "help",
	                      "userpassword=s",
	                      "uid=s",
	                      "pwmech=s",
	                      "mustchange",
	                      "sso"
	                      );
	
	if (!$result && ($#ARGV != -1))
	{
	      usage();
	      exit 1;
	}
	if ( defined($options{'help'}) ) {
	      usage();
	      exit 0;
	}
	if ( defined($options{'userpassword'}) )
	{
	      $userpassword=$options{'userpassword'};
	}
	if ( defined($options{'uid'}) )
	{
	      $uid=$options{'uid'};
	}
	if ( defined($options{'pwmech'}) )
	{
	      $pwmech=$options{'pwmech'};
	}
	if ( defined($options{'sso'}) )
	{
	      $sso=1;
	}
	if ( defined($options{'mustchange'}) )
	{
	      $mustchange=1;
	}
}

if( !$uid || !$userpassword )
{
  usage();
  exit 0;
}

##############################################################################
## Print the option usage
sub usage {

        print "oss_set_password.pl --userpassword <userpassword> --uid <uid> [<other options>]\n";
        print "Options:\n";
        print "  --help         print this help message\n";
        print "  --userpassword       the new userpassword\n";
        print "  --uid          the concerned user\n";
        print "  --pwmech       the required pasword hash mechanismus\n";
        print "  --sso          shows if single-sing-on is required\n";
        print "  --mustchange   shows if the user have to change the pasword\n\n";
        print "Otherwise you can pipe the attributes on STDIN (it is safer). In this case use '-' as option:\n\n";
        print "echo \"uid bigboss\n";
        print "userpassword Very#q%&Secur\n";
        print "sso\n";
        print "mustchange\" | oss_set_password.pl -\n\n";
}


##############################################################################
# now we start to work
if( ($uid eq "" && $dn eq "" ) || $userpassword eq "" )
{
  print STDERR "ERROR You have to define min <uid> and <userpassword>";
  exit 0;
}

# Make OSS Connection
if( defined $ENV{SUDO_USER} )
{
   if( ! defined $connect->{aDN} || ! defined $connect->{aPW} )
   {
       die "Using sudo you have to define the parameters aDN and aPW\n";
   }
}
my $oss = oss_base->new($connect);

if( $oss->get_school_config('SCHOOL_DEBUG') eq 'yes' )
{
  write_file("/tmp/set_passwd",$line);
}


if( $dn eq "" )
{
  if( $oid ne '' )
  {
    my $sdn = $oss->get_school_base($oid);
    $dn     = $oss->get_user_dn($uid,$sdn);
  }
  else
  {
    $dn  = $oss->get_user_dn($uid);
  }
}
$oss->set_password($dn,$userpassword,$mustchange,$sso,$pwmech);

#Starting the plugins
my $TMP = "$dn
uid $uid
userpassword $userpassword";
my $TMPFILE = write_tmp_file($TMP);
system("/usr/share/oss/plugins/plugin_handler.sh modify_user $TMPFILE");
$oss->destroy();
