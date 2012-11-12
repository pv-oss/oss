# LMD BackupSetWizard modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package BackupWizard;

use strict;
use oss_base;
use oss_utils;
use Data::Dumper;
use MIME::Base64;
use Storable qw(thaw freeze);
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
		"nfs",
		"usb_1",
		"usb_2",
		"usb_3",
		"iscsi",
		"create_backup",
		"refresh",
		"start_create_backup",
		"test_mount_dir",
		"set",
		"restore_backup",
		"start_restore_backup",
	];
}

sub getCapabilities
{
	return [
		 { title        => 'BackupWizard' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
#		 { allowedRole  => 'teachers,sysadmins' },
		 { category     => 'System' },
		 { order        => 49 },
		 { variable     => [ "nfs",                  [ type => "action" ] ] },
		 { variable     => [ "usb_1",                [ type => "action" ] ] },
		 { variable     => [ "iscsi",                [ type => "action" ] ] },
		 { variable     => [ "media_label",          [ type => "label" ] ] },
		 { variable     => [ "media",                [ type => "popup" ] ] },
		 { variable     => [ "rvalue",               [ type => "label",  label=>"value" ] ] },
		 { variable     => [ "svalue",               [ type => "string", label=>"value", style => "width:300px" ] ] },
		 { variable     => [ "pvalue",               [ type => "popup",  label=>"value" ] ] },
        ];
}

sub default
{
	my $this  = shift;
	my $reply = shift;

	if( -e "/var/adm/oss/BackupRunning"){
		return [
			{ NOTICE => "Runing Backup!"},
		]
	}

	if( -e "/var/adm/oss/Format_ext3_Running"){
		return [
			{ subtitle => "Create Backup / Format external storage device" },
			{ NOTICE => main::__("Please return to the page a bit later, because currently the external hard drive is being formatted.") },
			{ NOTICE => main::__("Please retry the backup creation a bit later, when the formatting has finished, the only difference would be that this time you do not need to format the external hard drive because that has already been formatted.") },
		]
	}

	my @create = ('c_mediums');
	push @create, { line=> [ '' ] };
	push @create, { line=> [ 'nfs', { nfs => main::__('nfs') }]};
	push @create, { line=> [ 'usb', { usb_1 => main::__('usb_1') }]};
#	push @create, { line=> [ 'iscsi', { iscsi => main::__('iscsi') }] };

	my @restore = ('r_mediums');
	push @restore, { line=> [ '' ] };
	push @restore, { line=> [ 'nfs', { nfs => main::__('nfs') }]};
	push @restore, { line=> [ 'usb', { usb_1 => main::__('usb_1') }]};
#	push @restore, { line=> [ 'iscsi', { iscsi => main::__('iscsi') }]};

	return [
		{ label => main::__('Create Backup') },
		{ table => \@create },
		{ label => main::__('Restore Backup') },
		{ table => \@restore },
	];
}

sub nfs
{
	my $this  = shift;
	my $reply = shift;
	my $mount_url = '';
	my $backup_full_dir = '';
	my @ret;

	if( $reply->{warning} ){
		$mount_url = $reply->{mount_url};
		$backup_full_dir = $reply->{backup_full_dir};
		push @ret, { NOTICE => "$reply->{warning}"};
	}else{
		$backup_full_dir = $this->get_school_config("SCHOOL_BACKUP_FULL_DIR");
	}

	push @ret, { NOTICE => main::__('Please provide the Server URL, which you want to mount!') };
	push @ret, { name => 'mount_url', value => "$mount_url", attributes => [type => "string", label => main::__("Please enter Server URL :"), style => "width:300px", help => main::__('example:')." 192.168.19.195:/backup"]};
	push @ret, { name => 'backup_full_dir', value => "$backup_full_dir", attributes => [ type => 'string', style => "width:300px"]};
	push @ret, { name => 'action_name', value => 'nfs', attributes => [ type => 'hidden' ] };
	push @ret, { action => 'cancel' };
	if( exists($reply->{r_mediums}) ){
		push @ret, { subtitle => main::__('NFS / Restore Backup') };
		push @ret, { action => 'restore_backup' };
	}else{
		push @ret, { subtitle => main::__('NFS / Create Backup') };
		push @ret, { action => 'create_backup' };
	}
	return \@ret;
}

sub usb_1
{
	my $this  = shift;
	my $reply = shift;
	my @ret;
	my $create_or_restore = '';
	if( exists($reply->{r_mediums}) ){
		$create_or_restore = 'r_mediums';
		push @ret, { subtitle => main::__('USB / Restore Backup') };
	}else{
		$create_or_restore = 'c_mediums';
		push @ret, { subtitle => main::__('USB / Create Backup') };
	}

	push @ret, { NOTICE => main::__('Please remove all external storage devices!') };
	push @ret, { name => "$create_or_restore", value => 1, attributes => [ type => 'hidden' ] };
	push @ret, { action => 'cancel' };
	push @ret, { action => 'usb_2' };
	return \@ret;
}

sub usb_2
{
	my $this  = shift;
	my $reply = shift;
	my @ret;
	my $create_or_restore = '';
        if( exists($reply->{r_mediums}) ){
                $create_or_restore = 'r_mediums';
		push @ret, { subtitle => main::__('USB / Restore Backup') };
        }else{
                $create_or_restore = 'c_mediums';
		push @ret, { subtitle => main::__('USB / Create Backup') };
        }
	my $hdd = `sfdisk -s | gawk -F: ' /dev/ { print \$1 }'`;

	push @ret, { NOTICE => main::__('Please connect the external storage device!')."<BR>".main::__('After connecting the external storage device please wait 5-10 seconds until the PC recognizes it and only after that hit the "next" button!') };
	push @ret, { name => 'hdd', value => "$hdd", attributes => [ type => 'hidden'] };
	push @ret, { name => "$create_or_restore", value => 1, attributes => [ type => 'hidden' ] };
	push @ret, { action => 'cancel' };
	push @ret, { action => 'usb_3' };
	return \@ret;
}

sub usb_3
{
	my $this  = shift;
	my $reply = shift;
	my @ret;
	my $backup_full_dir = '';
	my $format_ext3 = 0;
	my @splt_old_hdd = split("\n", $reply->{hdd});
	my @splt_hdd     = ();
	my $disks  = {};
	#Searching for usb devices
	my $hardware = `hwinfo --disk | grep -P 'Device File:|Device Files:|Size:|Model:'`;
	foreach ( split( "bytes\n", $hardware ) )
	{
		my ( $d  ) = ( /Device File: (\S+)/ );
		next if ( $reply->{hdd} =~ /$d/ );
		my ( $ds ) = ( /Device Files: (.*)/ );
		next if ( grep(/Device Files: .*\/dev\/cdrom/,$ds) );
		my ( $s )  = ( /Size: (\d+)/ );
		my ( $m )  = ( /Model: (.*)/ );
		$s = $s/2/1024/1024;
		$disks->{$d}->{size}  = $s;
		$disks->{$d}->{model} = $m;
		foreach my $dev ( split /,/, $ds )
		{
			if( $dev =~ /\/dev\/disk\/by-id\/.*/ )
			{
				$disks->{$d}->{dev} = $dev;
			}
		}
	}
	foreach my $d ( keys %$disks )
	{
		push @splt_hdd, [ $disks->{$d}->{dev}, $disks->{$d}->{model}." ".$disks->{$d}->{size}."GB" ];
	}	


	if( $reply->{warning} ){
		push @splt_hdd, "---DEFAULTS---", "$reply->{mount_url}";
                $backup_full_dir = $reply->{backup_full_dir};
		$format_ext3 = $reply->{format_ext3};
                push @ret, { NOTICE => "$reply->{warning}"};
        }else{
                $backup_full_dir = $this->get_school_config("SCHOOL_BACKUP_FULL_DIR");
        }

	push @ret, { name => 'mount_url', value => \@splt_hdd, attributes => [ type => "popup" ]};
	push @ret, { name => 'backup_full_dir', value => "$backup_full_dir", attributes => [ type => 'string', style => "width:300px"]};
	if( exists($reply->{c_mediums}) ){
		push @ret, { name => 'format_ext3', value => $format_ext3, attributes => [ type => "boolean" ]};
	}
	push @ret, { name => 'hdd', value => "$reply->{hdd}", attributes => [ type => 'hidden' ] };
	push @ret, { name => 'action_name', value => 'usb', attributes => [ type => 'hidden' ] };
	push @ret, { action => 'cancel' };
	if( exists($reply->{r_mediums}) ){
		push @ret, { subtitle => main::__('USB / Restore Backup') };
		push @ret, { NOTICE => main::__('Please select the right external storage device!')."<BR>" };
		push @ret, { action => 'restore_backup' };
	}else{
		push @ret, { action => 'create_backup' };
		push @ret, { NOTICE => main::__('Please select the right external storage device!')."<BR>".main::__('Please enter backup_full_dir!')."<BR>".main::__('Plese check the format_ext3 if you wish to format the extrenal storage device!') };
		push @ret, { subtitle => main::__('USB / Create Backup') };
	}
	return \@ret;
}

sub iscsi
{
	my $this  = shift;
	my $reply = shift;

	return [
		{ NOTICE => "Under construction!" },
	]
}

sub create_backup
{
	my $this  = shift;
	my $reply = shift;
	my @lines = ('backup');
	my @ret;

	my $warning = "";
	if( exists($reply->{mount_url}) and !$reply->{mount_url} ){
		$warning .= main::__('Please provide the Server URL (NFS) or select the mounting location (USB)! ( Ex: 192.168.19.199:/backup or /dev/sdb )')."<BR>";
	}
	if( exists($reply->{backup_full_dir}) and !$reply->{backup_full_dir} ){
		$warning .= main::__('Please provide the mount point! ( Ex: /mnt/backup )');
	}
	if( exists($reply->{mount_url}) and exists($reply->{backup_full_dir}) and $warning ){
		$reply->{c_mediums} = '1';
		$reply->{warning} = $warning;
		if( $reply->{action_name} eq "nfs"){
			return $this->nfs($reply);
		}
		if( $reply->{action_name} eq "usb" ){
			return $this->usb_3($reply);
		}
	}

	if( exists($reply->{format_ext3}) and !$reply->{format_ext3} ){
		my $hdd_file_system = cmd_pipe("parted -s ".$reply->{mount_url}."-part1 unit s print | awk '(NR > 6) && (NR < 8) { print \$5 }'");
#                print $hdd_file_system."--->hdd_filesyst\n";
                if( $hdd_file_system eq "ext3\n"){
                        $reply->{mount_url} = $reply->{mount_url}."-part1";
                }else{
                        $reply->{warning} = sprintf(main::__('The extrenal storage place is not "ext3" type with "%s1" file system, it is "%s"'), $reply->{mount_url}, $hdd_file_system)."<BR>".main::__('The external storage device has to be formated to "ext3" type so you can make a backup!');
                        return $this->usb_3($reply);
                }
	}
	if( exists($reply->{format_ext3}) and $reply->{format_ext3} ){
		my $HD = `readlink -f $reply->{mount_url}`;
		my ($empty, $path, $part_name) = split("/", $HD);

		# remove partitions
		my $parts = cmd_pipe("grep $part_name /proc/partitions");chomp($parts);
		my @splt_parts = split("\n",$parts);
		my $length = scalar(@splt_parts);
		for(my $i=1; $i <= $length; $i++){
			my $mount = cmd_pipe("df -h | grep -i $HD$1 | awk '{print \$6}'");
			if( $mount ){
				cmd_pipe("umount $mount");
			}
			my $rm_part_err = cmd_pipe("parted -s $HD rm $i");
#		print $rm_part_err."---->rm_part_err\n";
		}

		# get HDD size
		my $hdd_size = cmd_pipe("parted -s $HD unit s print | grep -i \"Disk $HD\" | awk '{print substr(\$NF,0,length(\$NF)-1)}'");
		$hdd_size = $hdd_size - 70;

		# create one partition Ex: /dev/sdb1
		my $create_part_err = cmd_pipe("parted -s $HD unit s mkpart primary ext3 63 $hdd_size;");
		sleep 3;
		# unmount new device, because without not go formatting
		my $mount = cmd_pipe("df -h | grep -i $HD | awk '{print \$6}'");
		if( $mount ){
			cmd_pipe("umount $mount");
		}
		#formatting partition
		$reply->{mount_url} = $reply->{mount_url}."-part1";
		system("/usr/share/oss/tools/format_ext3_backup.sh --disk_path=".$reply->{mount_url}." &");

		return[
			{ subtitle => "Create Backup / Format external storage device" },
			{ NOTICE => "The formatting of an external HDD can last from 1 minute up to 10 minutes depending of the size. For this reason please press the Refresh button, so we can move forward with the backup making procedure."},
			{ name => 'mount_url', value => "$reply->{mount_url}", attributes => [ type => 'hidden'] },
			{ name => 'backup_full_dir', value => "$reply->{backup_full_dir}", attributes => [ type => 'hidden'] },
			{ action => 'refresh'},
		]
#		my $tt = cmd_pipe("mkfs.ext3 $reply->{mount_url}");
#	print $create_part_err."----->create_part_err\n";
	}

	if( exists($reply->{mount_url}) and exists($reply->{backup_full_dir}) ){
		my $backup_start_cmd = 'umount '.$reply->{mount_url}.'; mount -o rw,acl '.$reply->{mount_url}.' '.$reply->{backup_full_dir};
		$this->set_school_config("SCHOOL_BACKUP_START_CMD",$backup_start_cmd);
		my $backup_stop_cmd  = "umount $reply->{backup_full_dir}";
		$this->set_school_config("SCHOOL_BACKUP_STOP_CMD",$backup_stop_cmd);
		$this->set_school_config("SCHOOL_BACKUP_FULL_DIR",$reply->{backup_full_dir});
		$this->set_school_config("SCHOOL_BACKUP_INC_DIR",$reply->{backup_full_dir});
		$this->set_school_config("SCHOOL_BACKUP","yes");
		$this->set_school_config("SCHOOL_BACKUP_CAN_NOT_SAVE_ACL","no");
		$this->set_school_config("SCHOOL_BACKUP_CHECK_MOUNT","yes");
		system("/usr/sbin/oss_ldap_to_sysconfig.pl");
	}

	if( !(-e "$reply->{backup_full_dir}") ){
		system("mkdir -p $reply->{backup_full_dir}");
	}


	my $mesg      = $this->{LDAP}->search( base   => $this->{SYSCONFIG_BASE},
                              filter => "(objectClass=SchoolConfiguration)",
                              scope   => 'one'
                            );
	foreach my $entry ( $mesg->entries )
	{
		my @path    = split /\//, $entry->get_value('configurationPath');
		my $sec     = $path[2];
		if( $sec eq "Backup"){
			my $key     = $entry->get_value('configurationKey');
			my @avalue    = $entry->get_value('configurationAvailableValue');
			my $value         = $entry->get_value('configurationValue');
			my $type          = $entry->get_value('configurationValueType');
			my $description   = main::__($entry->get_value('description')) || '';
			$description   =~ s/"/ /g;
			my $ro            = $entry->get_value('configurationValueRO');
			my $tmp = $key; $tmp =~ s/^SCHOOL_|OSS_//;
			my $name          = $tmp;

			if( $type eq 'yesno' )
			{
				push @avalue ,'yes','no', '---DEFAULTS---', $value;
				push @lines, { line => [ $key ,
                                                                { name => 'name', value => $name, attributes => [ type => 'label', help => "$description"]},
                                                                { pvalue => \@avalue } ] };
			}
			else
			{
				push @lines, { line => [ $key ,
								{ name => 'name', value => $name, attributes => [ type =>'label', help => "$description"]},
								{ svalue => $value } ] };
			}
		}   
	}

	push @ret, { subtitle => "Create Backup"};
	if( exists($reply->{warning}) ){
		push @ret, { NOTICE =>  "$reply->{warning}" };
	}
	push @ret, { table =>  \@lines };
	push @ret, { rightaction   => "set" };
	push @ret, { rightaction   => "test_mount_dir" };
	push @ret, { rightaction   => "start_create_backup" };
	push @ret, { rightaction   => "cancel" };

	return \@ret;
}

sub test_mount_dir
{
	my $this  = shift;
	my $reply = shift;

	my $tmp = $this->mount_test();
	if( $tmp ){
		$reply->{warning} = main::__('The path for the backup is successfully accessed (the mount was successful)');
	}else{
		$reply->{warning} = main::__('The path for the backup has failed (the mounting was unsuccessful)');
	}
	

	return $this->create_backup($reply);
}

sub mount_test
{
	my $this  = shift;
        my $mount_url = shift || '';
	my $backup_full_dir = shift || '';
	my $backap_start_cmd = '';
	my $backap_stop_cmd = '';

	cmd_pipe("umount $mount_url");

	if( $mount_url and $backup_full_dir ){
		$backap_start_cmd = "mount -o rw,acl $mount_url $backup_full_dir";
		$backap_stop_cmd = "umount $backup_full_dir";
	}else{
		$backap_start_cmd = $this->get_school_config("SCHOOL_BACKUP_START_CMD");
		$backap_stop_cmd = $this->get_school_config("SCHOOL_BACKUP_STOP_CMD");
	}
	#mount
        cmd_pipe("$backap_start_cmd");

	#check mount point
        my @splt = split(" ", $backap_start_cmd);
        my $size = scalar(@splt);
        my $search = $splt[$size-1]." ".$splt[$size];
        my $tmp = `grep "$search" /etc/mtab`;

	#umount
        cmd_pipe("$backap_stop_cmd");

	return $tmp;
}

sub refresh
{
	my $this  = shift;
	my $reply = shift;

	if( -e "/var/adm/oss/Format_ext3_Running"){
		return [
			{ subtitle => "Create Backup / Format external storage device" },
			{ NOTICE => "The formatting of an external HDD can last from 1 minute up to 10 minutes depending of the size. For this reason please press the Refresh button, so we can move forward with the backup making procedure."},
			{ name => 'mount_url', value => "$reply->{mount_url}", attributes => [ type => 'hidden'] },
			{ name => 'backup_full_dir', value => "$reply->{backup_full_dir}", attributes => [ type => 'hidden'] },
			{ action => "refresh"},
		]
	}

	$this->create_backup($reply);
}

sub start_create_backup
{
	my $this  = shift;
	my $reply = shift;

	system("/etc/cron.daily/oss-backup &");
	return [
		{ NOTICE => main::__('Start backup!') },
	]
}

sub set
{
        my $this   = shift;
        my $reply  = shift;

        foreach my $sec (keys %{$reply})
        {
                next if( ref($reply->{$sec}) ne 'HASH' );
                foreach my $key (keys %{$reply->{$sec}})
                {
                        if( defined $reply->{$sec}->{$key}->{pvalue} )
                        {
                                $this->set_school_config($key,$reply->{$sec}->{$key}->{pvalue});
                        }
                        elsif( defined $reply->{$sec}->{$key}->{svalue} )
                        {
                                $this->set_school_config($key,$reply->{$sec}->{$key}->{svalue});
                        }
                }
        }
        system("/usr/sbin/oss_ldap_to_sysconfig.pl");
        $this->create_backup();
}

sub restore_backup
{
	my $this  = shift;
	my $reply = shift;
	my @lines = ('restore_backup');

	my $warning = "";
	if( exists($reply->{mount_url}) and !$reply->{mount_url} ){
		$warning .= main::__('Please provide the Server URL (NFS) or select the mounting location (USB)! ( Ex: 192.168.19.199:/backup or /dev/sdb )')."<BR>";
	}
	if( exists($reply->{backup_full_dir}) and !$reply->{backup_full_dir} ){
		$warning .= main::__('Please provide the mount point! ( Ex: /mnt/backup )')."<BR>";
	}
	if( !(-e "$reply->{backup_full_dir}") ){
		system("mkdir -p $reply->{backup_full_dir}");
	}
	if($reply->{action_name} eq "usb"){
		$reply->{mount_url} = "$reply->{mount_url}1";
	}
	my $mount_command = "mount -o rw,acl $reply->{mount_url} $reply->{backup_full_dir}";
	if( $reply->{mount_url} and $reply->{backup_full_dir} ){
		my $tmp = $this->mount_test("$reply->{mount_url}", "$reply->{backup_full_dir}");
		if( $tmp ){
			$reply->{warning} .= main::__('The path for the backup is successfully accessed (the mount was successful)')."<BR>";
			$reply->{warning} .= sprintf(main::__('Mount command : "%s"'), $mount_command);
		}else{
			$warning .= main::__('The path for the backup has failed (the mounting was unsuccessful)')."<BR>";
			$warning .= sprintf(main::__('Mount command : "%s"'), $mount_command);
		}
	}

	if( exists($reply->{mount_url}) and exists($reply->{backup_full_dir}) and $warning ){
		$reply->{r_mediums} = '1';
		$reply->{warning} = $warning;
		if( $reply->{action_name} eq "nfs"){
			return $this->nfs($reply);
		}
		if( $reply->{action_name} eq "usb" ){
			return $this->usb_3($reply);
		}
	}

	cmd_pipe("$mount_command");
	sleep 1;
	my $tmp = cmd_pipe("$reply->{backup_full_dir}/oss_recover.sh --help");

	my @splt_tmp = split("\n", $tmp);

	push @lines, { line => [ "all" ,
					{ name => 'resrtore_option_name', value => "all", attributes => [ type => 'label' ] },
					{ name => 'enable_disable', value => "", attributes => [ type => 'boolean' ] },
		]};

	foreach my $line (@splt_tmp){
		if($line =~ /^(.*)--([A-Za-z]{1,25})/){
			if( $2 eq 'help'){next};
			push @lines, { line => [ "$2" ,
						{ name => 'resrtore_option_name', value => "$2", attributes => [ type => 'label' ] },
						{ name => 'enable_disable', value => "", attributes => [ type => 'boolean' ] },
				]};
		}

	}

	return [
		{ subtitle => main::__('Restore Backup') },
		{ NOTICE => main::__('When you start the "start_restore_backup" then the ossadmin platform will not be available for 4-5 minutes. If we are restoring only a specific sections then it will not last long.') },
		{ NOTICE => "$reply->{warning}"},
		{ table => \@lines },
		{ name => 'backup_full_dir', value => "$reply->{backup_full_dir}", attributes => [ type => 'hidden' ]},
		{ action => 'cancel' },
		{ action => 'start_restore_backup' },
	]
}

sub start_restore_backup
{
	my $this  = shift;
	my $reply = shift;
	my @ret;
	my $cmd = "cd $reply->{backup_full_dir}; ./oss_recover.sh ";

	if($reply->{restore_backup}->{all}->{enable_disable}){
		system("$cmd &");
		return [
			{ NOTICE => main::__('Start restore backup!')."<BR>".main::__('Please be patient because the restoring might take a minute or two. Then try to login into the ossadmin platform.') },
		]
	}else{
		delete $reply->{restore_backup}->{all};
		my $old_cmd = $cmd;
		foreach my $optione (keys %{$reply->{restore_backup}}){
			if($reply->{restore_backup}->{$optione}->{enable_disable}){
				$cmd .= "--".$optione." ";
			}
		}
		if( "$cmd" ne "$old_cmd" ){
			system("$cmd &");
			return [
				{ NOTICE => main::__('Start restore backup!')."<BR>".main::__('Please be patient because the restoring might take a minute or two. Then try to login into the ossadmin platform.') },
			]
		}
	}

	$reply->{warning} .= main::__('Please select what you want to restore!')."<BR>";
	$this->restore_backup($reply);
}

1;
