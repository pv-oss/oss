#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# (c) 2011 EXTIS GmbH
# Revision: $Rev: 1649 $

BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_base;
use oss_utils;
use XML::Simple;
use MIME::Base64;
use Config::IniFiles;
use Encode qw(encode decode);
use Data::Dumper;
use URI::Escape;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
                      );
sub usage
{
	print   'Usage: /usr/share/oss/tools/make_data_systemoverview.pl [OPTION]'."\n".
		'With this script we can refresh the information shown on the SystemOverview page.'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		"	No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'Optional parameters: '."\n".
		'	-h, --help         Display this help.'."\n".
		'	-d, --description  Display the descriptiont.'."\n";
}
if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	make_data_systemoverview.pl'."\n".
		'DESCRIPTION:'."\n".
		'	With this script we can refresh the information shown on the SystemOverview page.'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"		                  : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h, --help        : Display this help.(type=boolean)'."\n".
		'		-d, --description : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}

my $this     = oss_base->new();
my $language = uc(substr($this->{SYSCONFIG}->{SCHOOL_LANGUAGE},0,2));
my $message  = {};
my %hash;
my $school_dn = $this->{SCHOOL_BASE};
my $date = `date +%Y-%m-%d.%H-%M-%S`;
chop $date;

open STDIN,"/dev/null";
open STDOUT,">>/var/log/oss_make_data_systemoverview.log";
open STDERR,">>/var/log/oss_make_data_systemoverview.log";
print  "\n\n----------------------------------  $date  ------------------------------------\n"; 

if( ! -e '/usr/share/lmd/lang/base_'.$language.'.ini' )
{
	print 'Transaltaion file does not exists: /usr/share/lmd/lang/base_'.$language.'.ini';
	exit;
}
# Setup the messages
my $allmessages = new Config::IniFiles( -file => '/usr/share/lmd/lang/base_'.$language.'.ini' );
my @parameters = $allmessages->Parameters('SystemOverview');
foreach(@parameters)
{
	my $value = $allmessages->val('SystemOverview', $_);
	$message->{$_} = $value;
}


$this->delete_vendor_object( "$school_dn", 'extis','SystemOverview' );

#--------Software-----------------------------

#System
my $system_name = "Open School Server";
$this->create_vendor_object( "$school_dn",'extis','SystemOverview',"software#;#system_name#=#$system_name");

#System Version
my $system_version = `rpm -q --qf %{VERSION} openschool-base`;
my $sys_bit = `cat /etc/SuSE-release`;
my @line_sys = split("\n", $sys_bit);
if( $line_sys[0] =~ /(.*) \((.*)\)$/){
	if( $2 eq 'x86_64'){
		$sys_bit = '64 Bit';
	}else{
		$sys_bit = '32 Bit';
	}
}
	#KerenelVersion, SUSE_SLES, sle_skd
	my $help_Kernel_SLES_sdk = '';
	my @kernel_version = split("\n", `uname -m`);
	$kernel_version[0] .= " ";
	$kernel_version[0] .= `cat /proc/version | awk '{  print \$1 \" \" \$3  \"   \" \$11 \" \" \$12}'`;
	chomp($kernel_version[0]);
	$help_Kernel_SLES_sdk .= 'KernelVersion: '.$kernel_version[0].", ";
	my $xml = new XML::Simple;
	if(-e "/etc/products.d/SUSE_SLES.prod"){
		my $tmp = `cat /etc/products.d/SUSE_SLES.prod`;
		if( $tmp ){
			my $SLES = $xml->XMLin("/etc/products.d/SUSE_SLES.prod");
			my $SUSE_SLES = $SLES->{version};
			$help_Kernel_SLES_sdk .= __('SUSE_SLES : ').$SUSE_SLES.", ";
		}else{
			print "'/etc/products.d/SUSE_SLES.prod' file is empty!\n";
		}
	}else{
		print "'/etc/products.d/SUSE_SLES.prod' file is inexistent!\n";
	}
	if(-e "/etc/products.d/sle-sdk.prod"){
		my $tmp = `cat /etc/products.d/sle-sdk.prod`;
		if( $tmp ){
			my $sle = $xml->XMLin("/etc/products.d/sle-sdk.prod");
			my $sle_sdk = $sle->{version};
			$help_Kernel_SLES_sdk .= __('sle_sdk : ').$sle_sdk.", ";
		}else{
			print "'/etc/products.d/sle-sdk.prod' file is empty! (Possibly server registration was unsuccessful)\n";
		}
	}else{
		print "'/etc/products.d/sle-sdk.prod' file is inexistent! (Possibly server registration was unsuccessful)\n";
	}

$this->add_value_to_vendor_object( "$school_dn", 'extis', 'SystemOverview', "software#;#systemversion#=#$system_version $sys_bit#;#help#=#$help_Kernel_SLES_sdk");

#Last Update
my $lastupdate = "";
foreach my $f ( sort ( glob "/var/log/OSS-UPDATE*" ) ){
	if($f =~ /^\/var\/log\/OSS-UPDATE-(.*)/){
		my @date_time = split("-",$1);
		if(($language eq "DE") or ($language eq "RO")){
			$lastupdate = "$date_time[2].$date_time[1].$date_time[0]";
		}elsif($language eq "HU"){
			$lastupdate = "$date_time[0].$date_time[1].$date_time[2]";
		}
	}
}
if($lastupdate eq ''){
	$lastupdate = __("It has not been updated yet");
}
$this->add_value_to_vendor_object( "$school_dn", 'extis', 'SystemOverview', "software#;#lastupdate#=#$lastupdate");

#RegCode
my $school_regcode;
if(defined($this->{SYSCONFIG}->{SCHOOL_REG_CODE})){
	$school_regcode = $this->{SYSCONFIG}->{SCHOOL_REG_CODE};
}else{
	my $tmp = uri_escape("$system_version $sys_bit");
	$school_regcode = "<a href='http://www.openschoolserver.net/howtoregister?version=".$tmp."'>".__('Not registered')."</a>";
}
$this->add_value_to_vendor_object( "$school_dn", 'extis', 'SystemOverview', "software#;#school_regcode#=#$school_regcode");

#Licence-Information
#my $licenceinformation = __('The site is not accessible :'). "http://repo.openschoolserver.net/cgi-bin/validate-regcode.pl?regcode=$this->{SYSCONFIG}->{SCHOOL_REG_CODE}";
my $licenceinformation = __('Problem with internet access. The license and support status can not be determined.');
my $URL = "http://repo.openschoolserver.net/cgi-bin/validate-regcode.pl?regcode=$this->{SYSCONFIG}->{SCHOOL_REG_CODE}";
system("wget -O /tmp/url.txt $URL");
open(INFILE, "/tmp/url.txt") || die "Cannot open $URL";
while (<INFILE>) {
	if ($_ =~ /<h[0-9]>(.*)<\/h[0-9]>/) {
		my @date_time = split("-",$1);
		if(($language eq "DE") or ($language eq "RO")){
			$licenceinformation = "$date_time[2].$date_time[1].$date_time[0]";
		}elsif($language eq "HU"){
			$licenceinformation = "$date_time[0].$date_time[1].$date_time[2]";
		}
		if($date_time[0] !~ /(.*)[0-9]/){
			$licenceinformation = __("None, invalid or expired registration code");
			system("rm /var/adm/oss/registered");
		}
	}
}
close(INFILE);
$this->add_value_to_vendor_object( "$school_dn", 'extis', 'SystemOverview', "software#;#licenceinformation#=#$licenceinformation");

#SystemUpTime

#MonitorProcesses

#--------Hardware----------------------------------

#Processor Number and Name
my $cpu_pieces = 0;
my $proc_model_name;
my @cpu_info = split("\n", get_file("/proc/cpuinfo") );
foreach my $element (@cpu_info){
	if($element =~ /^processor(.*):/){
		$cpu_pieces++;
	}
	if($element =~ /^model name(.*)(: )(.*)$/){
		$proc_model_name = $3;
	}
}
$this->add_value_to_vendor_object( "$school_dn", 'extis', 'SystemOverview', "hardware#;#processor_number#=#$cpu_pieces");
$this->add_value_to_vendor_object( "$school_dn", 'extis', 'SystemOverview', "hardware#;#processor_name#=#$proc_model_name");

#Main Memory
my $main_memory = `free -m | awk '{ if(\$1 ~ /Mem:/){ print \$2 }}'`;
$main_memory = $main_memory/1000;
$this->add_value_to_vendor_object( "$school_dn", 'extis', 'SystemOverview', "hardware#;#main_memory#=#$main_memory G");

#---------Domain-------------------------------

#DomainName
my $domainname = $this->{SYSCONFIG}->{SCHOOL_DOMAIN};
$this->add_value_to_vendor_object( "$school_dn", 'extis', 'SystemOverview', "domain#;#domainname#=#$domainname");

#SambaDomain
my $sambadomain;
my $mesg      = $this->{LDAP}->search( base   => $this->{LDAP_BASE},
				       filter => "(&(objectClass=sambaDomain)(sambaDomainName=*))",
				       scope   => 'one'
				);
	foreach my $entry ( $mesg->entries )
	{
		$sambadomain    = $entry->get_value('sambaDomainName');
	}
	$this->add_value_to_vendor_object( "$school_dn", 'extis', 'SystemOverview', "domain#;#sambadomain#=#$sambadomain");

	#LDAP_base
	my $ldapbaseDN = $this->{LDAP_BASE};
	$this->add_value_to_vendor_object( "$school_dn", 'extis', 'SystemOverview', "domain#;#ldapbaseDN#=#$ldapbaseDN");

#---------Status Processor---------------------
my $counter = 0;
my $info_sda = cmd_pipe('df -h > /tmp/sd_infos | /usr/sbin/oss_correct_ldif.pl /tmp/sd_infos | awk \'NR > 1 { if($1 !~ /^(.*)tmpfs/){ print $1" "$2" "$3" "$4" "$5" "$6 }}\'');
my @infosda = split("\n", $info_sda);
@infosda = sort(@infosda);
foreach my $infos (@infosda){
	my ($filesystem, $size, $used, $avail, $use, $mounted_on) = split(" ",$infos);
	my $use_disk_file = get_file("/usr/share/lmd/tools/pchart/use_disk.php.tmp");
	$use =~ s/%//;
	my $free = 100-$use;

	my $used_space = $used;
	my $free_space = $avail;

	my $free_space_label = __('Free space');
	$use_disk_file =~ s/#free_space_label#/$free_space_label/g;
	$use_disk_file =~ s/#free_space#/$free_space/g;

	my $used_space_label = __('Used space');
	$use_disk_file =~ s/#used_space_label#/$used_space_label/g;
	$use_disk_file =~ s/#used_space#/$used_space/g;

	$use_disk_file =~ s/#used#/$use/g;
	$use_disk_file =~ s/#free#/$free/g;

	$use_disk_file =~ s/#sda_name#/$filesystem/g;
	$use_disk_file =~ s/#disk_name#/$mounted_on/g;

	my $mounted = decode("utf8", __('mounted') );
	$use_disk_file =~ s/#mounted#/$mounted/g;
	$use_disk_file =~ s/#png_name#/$counter/g;

	write_file('/usr/share/lmd/tools/pchart/use_disk.php',$use_disk_file);
	system(`cd /usr/share/lmd/tools/pchart/ ; php use_disk.php`);

	$this->add_value_to_vendor_object( "$school_dn", 'extis', 'SystemOverview', "disk_usage#;#/usr/share/lmd/tools/pchart/$counter.png");
	$counter++;
}

sub getActiveProcesses
{
	my $runlevel = `runlevel |awk '{ print \$(NF) }'`;
	my $rl = eval (2 +$runlevel) ;
	my $r  = eval $runlevel ;
	my $args = "chkconfig -l | awk '/$r/ {print "."\$"."1, \$".$rl."}' | sed 's/$r"."://'";
	my @proc_table = `$args`;
	my %processes = ();
	foreach my $pr (@proc_table) {
		my @tproc = split " ", $pr;
		if (($tproc[1]) eq "on") {
			$processes{$tproc[0]} = $tproc[1];
		}
	}
	return (%processes);
}

sub __($)
{
	my $i = shift;
	return $message->{$i} ? $message->{$i} : $i;
}
