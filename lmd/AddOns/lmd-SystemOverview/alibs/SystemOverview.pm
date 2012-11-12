# LMD MonitorProcesses modul

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package SystemOverview;

use strict;
use oss_base;
use oss_utils;
use Data::Dumper;
use XML::Simple;
use MIME::Base64;
use vars qw(@ISA);
@ISA = qw(oss_base);

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    my $self    = oss_base->new($connect);
    return bless $self, $this;
}


sub interface
{
        return [
                "getCapabilities",
                "default",
                "set"
        ];
}

sub getCapabilities
{
        return [
                { title        => 'SystemOverview' },
                { type         => 'command' },
                { allowedRole  => 'root' },
                { allowedRole  => 'sysadmins' },
                { category     => 'System' },
                { order        => 1 },
                { variable     => [  "img"                => [ type => 'img', style => 'width:350px;'  ]]},
		{ variable     => [  "name"               => [ type => 'label', style => 'width:150px;' ]]},
		{ variable     => [  "value"              => [ type => 'label' ]]},
		{ variable     => [  "HostName"           => [ type => 'label', label => main::__('Host Name'), style => 'width:150px;' ]]},
		{ variable     => [  "DomainName"         => [ type => 'label', label => main::__('Domain Name'), style => 'width:150px;' ]]},
		{ variable     => [  "SambaDomain"        => [ type => 'label', label => main::__('Samba Domain'), style => 'width:150px;' ]]},
		{ variable     => [  "LdapBaseDN"         => [ type => 'label', label => main::__('Ldap-Base-DN'), style => 'width:150px;' ]]},
		{ variable     => [  "Processor"          => [ type => 'label', label => main::__('Processor'), style => 'width:150px;' ]]},
		{ variable     => [  "MainMemory"         => [ type => 'label', label => main::__('Main Memory'), style => 'width:150px;' ]]},
		{ variable     => [  "SystemVersion"      => [ type => 'label', label => main::__('System Version'), style => 'width:150px;' ]]},
		{ variable     => [  "KernelVersion"      => [ type => 'label', label => main::__('Kernel Version'), style => 'width:150px;' ]]},
		{ variable     => [  "SystemUpTime"       => [ type => 'label', label => main::__('System Uptime'), style => 'width:150px;' ]]},
		{ variable     => [  "LastUpdate"         => [ type => 'label', label => main::__('Last Update'), style => 'width:150px;' ]]},
		{ variable     => [  "Regcode"            => [ type => 'label', label => main::__('Regcode'), style => 'width:150px;' ]]},
		{ variable     => [  "LicenceInformation" => [ type => 'label', label => main::__('Licence Information'), style => 'width:150px;' ]]},
                ];
}

sub default
{
        my $this        = shift;
        my $reply       = shift;
	my @ret;
	my @system     = ('system');
	push @system, {head => ['', '' ]};
	my @disk_usage = ('diskusage');
	push @disk_usage, {head => ['', '' ]};
	my @images_base64;

	my $info_sda = `df -h |awk '{ if(\$1 ~ \/\^\\/dev\\/sda[0-9]/){ print \$1 \" \" \$2 \" \" \$3 \" \" \$4 \" \" \$5 \" \" \$6 }}'`;
	my @infosda = split("\n", $info_sda);
	@infosda = sort(@infosda);
	foreach my $infos (@infosda){
		my ($filesystem, $size, $used, $avail, $use, $mounted_on) = split(" ",$infos);
		my $use_disk_file = get_file("/usr/share/lmd/tools/pchart/use_disk.php.tmp");
		$use =~ s/%//;
		my $free = 100-$use;
		my $sda;
		if($filesystem =~ /^\/dev\/(sda)([0-9])/){
                        $sda = $1."".$2;
                }
		$used =~ s/G//;
		$avail =~ s/G//;
		my $free_space = $avail;
		$free_space .= " G";
		$used .= " G";

		$use_disk_file =~ s/#free_space#/$free_space/g;
		$use_disk_file =~ s/#used_space#/$used/g;
		$use_disk_file =~ s/#used#/$use/g;
		$use_disk_file =~ s/#free#/$free/g;
		$use_disk_file =~ s/#sda_name#/$sda/g;
		$use_disk_file =~ s/#disk_name#/$mounted_on/g;

		write_file('/usr/share/lmd/tools/pchart/use_disk.php',$use_disk_file);
		system(`cd /usr/share/lmd/tools/pchart/ ; php use_disk.php`);

		my $img_file   = `base64 /usr/share/lmd/tools/pchart/$sda.png`;
		push @images_base64, $img_file;
	}

	my $size = scalar(@images_base64);
	for(my $i = 0; $i < $size-2; $i++){
		if($i eq 0){
			push @disk_usage, {line => ['dsk_usg', {img => "$images_base64[$i]"}, {img => "$images_base64[$i+1]"} ]};
		}else{
			push @disk_usage, {line => ['dsk_usg', {img => "$images_base64[$i+1]"}, {img => "$images_base64[$i+2]"} ]};
		}
	}

	#get System Version
	my $xml = new XML::Simple;
	my $sle_skd = "";
	my $SUSE_SLES = "";
	if(-e "/etc/products.d/sle-sdk.prod"){
		my $sle = $xml->XMLin("/etc/products.d/sle-sdk.prod");
		$sle_skd = $sle->{version};
	}
	if(-e "/etc/products.d/SUSE_SLES.prod"){
		my $SLES = $xml->XMLin("/etc/products.d/SUSE_SLES.prod");
		$SUSE_SLES = $SLES->{version};
	}

	my $basa = `rpm -q --qf %{VERSION} openschool-base`;
	my $lmd = `rpm -q --qf %{VERSION} lmd`;
	my $systemversion = 'Open School Server : '.$basa.'<br>LMD : '.$lmd.'<br>sle_skd : '.$sle_skd.'<br>SUSE_SLES : '.$SUSE_SLES;
	push @system, { line => [ 'systemversion', { name => 'SystemVersion' }, { value   =>  "$systemversion"} ]};

	#get kernel version
	my $kernel_version = `uname -m`;
	$kernel_version .= `cat /proc/version | awk '{  print \$1 \" \" \$3  \"   \" \$11 \" \" \$12}'`;
	push @system, { line => [ 'kernel_version', { name => 'KernelVersion' }, { value   =>  "$kernel_version"} ]};

	#get Last Update
	my $lastupdate;
	foreach my $f ( sort ( glob "/var/log/OSS-UPDATE*" ) ){
			if($f =~ /^\/var\/log\/OSS-UPDATE-(.*)/){
			$lastupdate = $1;
		}
	}
	push @system, { line => [ 'lastupdate', { name => 'LastUpdate' }, { value   =>  "$lastupdate"} ]};

	#get systemuptime
	my $systemuptime = `uptime | awk '{  print \$3 \" days, \" \$5  }'`;
	my @tmp = split(',',$systemuptime);
	if($tmp[2] eq ' users'){
		push @system, { line => [ 'systemuptime', { name => 'SystemUpTime' }, { value   =>  "$tmp[0]"} ]};
	}else{
		push @system, { line => [ 'systemuptime', { name => 'SystemUpTime' }, { value   =>  "$systemuptime"} ]};
	}

	#get RegCode
	my $school_regcode;
	if(defined($this->{SYSCONFIG}->{SCHOOL_REG_CODE})){
		$school_regcode = $this->{SYSCONFIG}->{SCHOOL_REG_CODE};
	}else{
		$school_regcode = 'http://www.openschoolserver.net/howtoregister?version=ossversion';
	}
	push @system, { line => [ 'school_regcode', { name => 'Regcode' }, { value   =>  "$school_regcode"} ]};

	#get LicenceInformation
	my $licenceinformation = "http://repo.openschoolserver.net/cgi-bin/validate-regcode.pl?regcode=$this->{SYSCONFIG}->{SCHOOL_REG_CODE}";
	push @system, { line => [ 'licenceinformation', { name => 'LicenceInformation' }, { value   =>  "$licenceinformation"} ]};

	#get Domain_name
	my $domainname = $this->{SYSCONFIG}->{SCHOOL_DOMAIN};
	push @system, { line => [ 'domainname', { name => 'DomainName' }, { value   =>  "$domainname"} ]};

	#get sambadomain
	my $sambadomain;
	my $mesg      = $this->{LDAP}->search( base   => $this->{LDAP_BASE},
                              filter => "(&(objectClass=sambaDomain)(sambaDomainName=*))",
                              scope   => 'one'
                            );
	foreach my $entry ( $mesg->entries )
	{
		$sambadomain    = $entry->get_value('sambaDomainName');
	}
	push @system, { line => [ 'sambadomain', { name => 'SambaDomain' }, { value   =>  "$sambadomain"} ]};

	#get Ldap-Base-DN
	my $ldapbaseDN = $this->{LDAP_BASE};
	push @system, { line => [ 'ldapbaseDN', { name => 'LdapBaseDN' }, { value   =>  "$ldapbaseDN"} ]};

	#get Processor
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
	my $processor = "Stuck  : $cpu_pieces <br> Name : $proc_model_name";
	push @system, { line => [ 'processor', { name => 'Processor' }, { value   =>  "$processor"} ]};

	#get main memory
	my $main_memory = `free -m | awk '{ if(\$1 ~ /Mem:/){ print \$2 }}'`;
	$main_memory = $main_memory/1000;
	push @system, { line => [ 'main_memory', { name => 'MainMemory' }, { value   =>  "$main_memory G"} ]};


        push @ret, { label => 'System' };
	push @ret, { table => \@system };
	push @ret, { label => 'Disk usage' };
        push @ret, { table => \@disk_usage };
	return \@ret;
}

1;

