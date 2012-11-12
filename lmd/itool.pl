#!/usr/bin/perl
#
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# itool.pl
#

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

$| = 1; # do not buffer stdout

use strict;
use oss_base;
use oss_utils;
use Data::Dumper;

use CGI;
use CGI qw(-no_xhtml);
use CGI::Carp qw(fatalsToBrowser);
use subs qw(exit);
# Select the correct exit function
*exit = $ENV{MOD_PERL} ? \&Apache::exit : sub { CORE::exit };

my $cgi=new CGI;

my $user    = $cgi->param("USER");
my $pass    = $cgi->param("PASS");
my $action  = $cgi->param("ACTION");
my $connect = { aDN => 'anon' };

if( defined $user and defined $pass ){
	my $this = oss_base->new($connect);
	my $dn = $this->get_user_dn("$user");
	$this->destroy();
	$connect = { aDN => "$dn", aPW => "$pass"};
}
my $oss = oss_base->new($connect);

=item
Ex: 
   wget -O 1.txt --no-check-certificate "https://admin/cgi-bin/itool.pl?ACTION=getHW&IP=172.16.2.1" 
=cut
=item
if( $action eq 'getHW' )
{
	my $ip  = $cgi->param("IP");
	if( !defined $ip )
	{
	   $ip  = $cgi->remote_addr();
	}
	my $wdn = $oss->get_host($ip);
	my $hw  = $oss->get_config_value($wdn,'HW');

	print $cgi->header(-charset=>'utf-8');
	print $cgi->start_html(-title=>'itool');
	print "HW $hw\n";
	print $cgi->end_html();
}

=item
Ex: 
   wget -O 1.txt --no-check-certificate "https://admin/cgi-bin/itool.pl?ACTION=getPCN&IP=172.16.2.1" 
=cut
if( $action eq 'getPCN' )
{
        my $ip  = $cgi->param("IP");
	my $pc_name = "-";
        if( !defined $ip )
        {
           $ip  = $cgi->remote_addr();
        }
        my $wdn = $oss->get_host($ip);
	my $tmp = $oss->get_attribute( $wdn, 'cn');
	if($tmp){
		$pc_name = $tmp;
	}

        print $cgi->header(-charset=>'utf-8');
        print $cgi->start_html(-title=>'itool');
        print "PCN $pc_name\n";
        print $cgi->end_html();
}

=item
Ex: 
   wget -O 1.txt --no-check-certificate "https://admin/cgi-bin/itool.pl?ACTION=getDOMAIN" 
=cut
if( $action eq 'getDOMAIN' )
{
	my $sambadomain = "-";
	my $mesg      = $oss->{LDAP}->search( base   => $oss->{LDAP_BASE},
					      filter => "(&(objectClass=sambaDomain)(sambaDomainName=*))",
					      scope   => 'one'
					);
	foreach my $entry ( $mesg->entries ){
		$sambadomain    = $entry->get_value('sambaDomainName');
	}

	print $cgi->header(-charset=>'utf-8');
	print $cgi->start_html(-title=>'itool');
	print "DOMAIN $sambadomain\n";
	print $cgi->end_html();
}

=item
Ex: 
   wget -O 1.txt --no-check-certificate "https://admin/cgi-bin/itool.pl?ACTION=getRESTORE&IP=172.16.2.1" 
=cut
if( $action eq 'getINSTALLATIONS' )
{
        my $ip  = $cgi->param("IP");
	my $packages = "";
	
        if( !defined $ip )
        {
           $ip  = $cgi->remote_addr();
        }

        my $ws_dn = $oss->get_host($ip);
	my $hostname = $oss->get_attribute($ws_dn,'cn');
	my $ws_user_dn = $oss->get_user_dn($hostname);
	$ws_user_dn = 'o=oss,'.$ws_user_dn;
	my $obj = $oss->search_vendor_object_for_vendor( 'osssoftware', "$ws_user_dn");
	if( scalar(@$obj) > 0 ){
		foreach my $sw_user_dn ( @$obj ){
			my $sw_name   = $oss->get_attribute($sw_user_dn,'configurationKey');
			my $sw_dn     = "configurationKey=$sw_name,o=osssoftware,".$oss->{SYSCONFIG}->{COMPUTERS_BASE};
			my $sw_type   = $oss->get_config_value($sw_dn,'TYPE');
			my $sw_status = $oss->get_attribute($sw_user_dn,'configurationValue');
			my $sw_options_inst = '';
			if ( $sw_status eq 'installation_scheduled' ){
				$sw_options_inst = $oss->get_config_value($sw_dn,'OPTIONS_INSTALLATION') || '-';
			} elsif ( $sw_status eq 'deinstallation_scheduled' ){
				$sw_options_inst = $oss->get_config_value($sw_dn,'OPTIONS_DEINSTALLATION') || '-';
			}
			my $tmp = cmd_pipe("ls /srv/itool/swrepository/$sw_name/*.msi");
			$tmp =~ /^\/srv\/itool\/swrepository\/$sw_name\/(.*\.msi).*/;
			my $installkit = $1;
			$sw_options_inst =~ s/PACKAGE/"I:\\swrepository\\$sw_name\\$installkit"/;
			$packages .= "getINSTALLATIONS\$".$sw_name."##".$sw_type."##".$sw_status."##".$sw_options_inst."\n";
		}
	}else{
		$packages = "getINSTALLATIONS\$-";
	}


        print $cgi->header(-charset=>'utf-8');
        print $cgi->start_html(-title=>'itool');
        print $packages;
        print $cgi->end_html();
}

=item
Ex: 
   wget -O 1.txt --no-check-certificate "https://admin/cgi-bin/itool.pl?USER=admin&PASS=admin_passw&ACTION=insertDIFF&DIFFNAME=test_diff_name&DIFFDESC=Test Diff Description.&VERSION=3.2" 
=cut
if( $action eq 'insertDIFF' )
{
	my $name        = $cgi->param("DIFFNAME");
	my $description = $cgi->param("DIFFDESC") || "";
	my $version     = $cgi->param("VERSION") || "";
	my $pc_dn       = $oss->{SYSCONFIG}->{COMPUTERS_BASE};
	my $msg         = "DIFFNAME_IS_MISSING";

	if( defined $name )
        {
	   $name =~ s/-/_/g;
	   $name =~ s/\s/_/g;
	   my $values = $oss->get_vendor_object( $pc_dn, 'osssoftware', "$name");
	   if( $values->[0] ){
		$msg .= "EXIST";
	   }
	   else
	   {
		$oss->create_vendor_object( $pc_dn, 'osssoftware', "$name", "NAME=$name");
		$oss->add_value_to_vendor_object( $pc_dn, 'osssoftware', "$name", "DESCRITION=$description");
		$oss->add_value_to_vendor_object( $pc_dn, 'osssoftware', "$name", "VERSION=$version");
		$oss->add_value_to_vendor_object( $pc_dn, 'osssoftware', "$name", "TYPE=DISKDIFF");
		$msg = "OK";
	   }
	}

        print $cgi->header(-charset=>'utf-8');
        print $cgi->start_html(-title=>'itool');
        print "insertDIFF $msg\n";
        print $cgi->end_html();
}

=item
Ex: 
   wget -O 1.txt --no-check-certificate "https://admin/cgi-bin/itool.pl?USER=admin&PASS=admin_passw&ACTION=setINSTALLATIONS&IP=172.16.2.1&SW_NAME=adobe&INST_STATUS=installed" 
inst_status: installed, installation_failed, deinstalled
=cut
if( $action eq 'setINSTALLATIONS' )
{
        my $ip      = $cgi->param("IP");
	my $sw_name = $cgi->param("SW_NAME");
	my $inst_status = $cgi->param("INST_STATUS");
        my $msg = "-";
	my %hash;

        if( !defined $ip )
        {
           $ip  = $cgi->remote_addr();
        }

	if( defined $sw_name and defined $inst_status ){
		my $ws_dn      = $oss->get_host($ip);
		my $hostname   = $oss->get_attribute($ws_dn,'cn');
		my $ws_user_dn = $oss->get_user_dn($hostname);
		$ws_user_dn = 'o=oss,'.$ws_user_dn;
		if( $inst_status eq 'deinstalled' ){
			$oss->delete_vendor_object( "$ws_user_dn", 'osssoftware', $sw_name );
			cmd_pipe("rm /srv/itool/swrepository/$sw_name/log/$hostname.log");
			$msg = 'OK';
		}elsif( ($inst_status eq 'installed') or ($inst_status eq 'installation_failed') or ($inst_status eq 'deinstallation_failed') ){
			if( $oss->modify_vendor_object( "$ws_user_dn", 'osssoftware', "$sw_name", "$inst_status") eq undef ){
				$msg = 'NOT_OK';
			}else{
				$msg = "OK";
			}
		}
	}elsif( !defined $sw_name ){
		$msg = "SW_NAME_IS_MISSING";
	}elsif( !defined $inst_status ){
		$msg = "INST_STATUS_IS_MISSING";
	}

        print $cgi->header(-charset=>'utf-8');
        print $cgi->start_html(-title=>'itool');
        print "setINSTALLATIONS $msg\n";
        print $cgi->end_html();
}
