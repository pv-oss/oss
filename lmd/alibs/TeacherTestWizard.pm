# LMD TeacherTestWizard  modul
# Copyright (c) 2012 EXTIS GmbH, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package TeacherTestWizard;

use strict;
use oss_base;
use oss_utils;
use oss_pedagogic;
use MIME::Base64;
use Storable qw(thaw freeze);
use vars qw(@ISA);
use Data::Dumper;
use DBI;
@ISA = qw(oss_pedagogic);

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    my $self    = oss_pedagogic->new($connect);
    return bless $self, $this;
}

sub interface
{
	return [
		"getCapabilities",
		"default",
		"open_test_info",
		"test_del",
		"realy_delete",
		"test_continue",
		"test_close",
		"close",
		"create_new_test",
		"step0",
		"step1",
		"step2",
                "step3",
                "step4",
                "step5",
                "step6",
		"step7",
		"refresh",
		"back",
		"en_dis_internet",
		"en_dis_windowslogin",
		"save",
		"filetree_dir_open",
		"post_it",
		"openDir",
		"get_it",
		"download_this_list",
	];
}


sub getCapabilities
{
	return [
		{ title        => 'TeacherTestWizard' },
		{ type         => 'command' },
		{ allowedRole  => 'root' },
		{ allowedRole  => 'sysadmins' },
		{ allowedRole  => 'teachers' },
		{ allowedRole  => 'teachers,sysadmins' },
		{ category     => 'Students' },
		{ order        => 6 },
		{ variable     => [ "test_status",                     [ type => "label" ] ] },
		{ variable     => [ "open_test_info",                  [ type => "action", label => main::__("open_test_info") ] ] },
		{ variable     => [ "test_del",                        [ type => "action", label => main::__("delete") ] ] },
		{ variable     => [ "test_continue",                   [ type => "action", label => main::__("test_continue") ] ] },
		{ variable     => [ "test_close",                      [ type => "action", label => main::__("close") ] ] },
		{ variable     => [ "pc_name",                         [ type => "label" ]]},
		{ variable     => [ "user",                            [ type => "label" ]]},
		{ variable     => [ "user_name",                       [ type => "label" ]]},
		{ variable     => [ "path",                            [ type => "filetree", label=>"My Documents", can_choose_dir => "true" ] ] },
		{ variable     => [ "file",                            [ type => "filefield" ] ] },
		{ variable     => [ "users",                           [ type => "list", size=>"15", multiple=>"true" ] ] },
		{ variable     => [ "clear_import",                    [ type => "boolean"] ] },
		{ variable     => [ "clear_export",                    [ type => "boolean"] ] },
		{ variable     => [ "test_id",                         [ type => "hidden"] ] },
		{ variable     => [ "act_room_dn",                     [ type => "hidden" ] ] },
		{ variable     => [ "actual_page",                     [ type => "hidden" ] ] },
	];
}

sub openDir
{
	my $this   = shift;
	my $reply  = shift;
	$this->default($reply);
}

sub filetree_dir_open
{
	my $this   = shift;
	my $reply  = shift;
	$this->step4($reply);
}

sub default
{
	my $this   = shift;
	my $reply  = shift;
	my $actuale_room_dn = $this->get_room_by_name(main::GetSessionValue('room'));
	my $user_uid = $this->get_attribute(main::GetSessionValue('dn'),'uid');

	my $sth = $this->{DBH}->prepare("SELECT Id, TestName, ExaminerTeacher, TestRoom, TestDir, CurrentStep, StartTime, EndTime FROM TestWizard WHERE ExaminerTeacher=\"$user_uid\"");  $sth->execute;
	my $result = $sth->fetchall_hashref('TestName');

	my @lines = ('tests');
	foreach my $test_name ( sort keys %{$result}){
		my $test_dir = $result->{$test_name}->{TestDir};
		if( $result->{$test_name}->{EndTime} ne '0000-00-00 00:00:00' ){
			push @lines, {line => [ "$result->{$test_name}->{Id}",
						{ name => "test_name", value => "$test_name", attributes => [ type => 'label', help => "$test_dir"] },
						{ test_status => main::__("closed") },
						{ open_test_info => main::__("open_test_info") },
						{ test_del => main::__("delete") },
						{ name => "test_continue", value => "", attributes => [ type => 'label'] },
						{ name => "test_close", value => "", attributes => [ type => 'label'] },
				]}
		}else{
			push @lines, {line => [ "$result->{$test_name}->{Id}",
						{ name => "test_name", value => "$test_name", attributes => [ type => 'label', help => "$test_dir"]},
						{ test_status => main::__("open") },
						{ open_test_info => main::__("open_test_info") },
						{ test_del => main::__("delete") },
						{ test_continue => main::__("test_continue") },
						{ test_close => main::__("close") },
						{ act_room_dn => $actuale_room_dn },
			]}
		}
	}

	my @ret;
	push @ret, { table => \@lines};
	push @ret, { action => "create_new_test"};
	push @ret, { act_room_dn => $actuale_room_dn };
	return \@ret;
}

sub test_del
{
	my $this   = shift;
	my $reply  = shift;
	my @ret;

	my $sth = $this->{DBH}->prepare("SELECT Id, TestName, TestDir FROM TestWizard WHERE Id=\'$reply->{line}\'");
	$sth->execute;
	my $result = $sth->fetchrow_hashref();

	push @ret, { subtitle => $result->{TestName}." ".main::__('test deleted')};
	push @ret, { NOTICE => sprintf(main::__('Are you sure you want to delete the "%s" exam?'),$result->{TestName})};
	push @ret, { label => main::__('The following files and libraries will be deleted, by deleting the exam:') };

	my $pth = `ls -Rp $result->{TestDir}`;
	my @splt_pth = split("\n\n",$pth);
	foreach my $gr ( @splt_pth ){
		my @splt_gr = split("\n",$gr);
		my $dir = shift(@splt_gr);
		chomp($dir); $dir =~ s/:/\//; $dir =~s/\/\//\//;
		push @ret, { name => 'del_file', value => "$dir<BR>", attributes => [ type => 'label', label => '']};
		foreach my $line (@splt_gr){
			chomp($line); if($line =~ /^(.*)\/$/){next}
			push @ret, { name => 'del_file', value => "$dir$line<BR>", attributes => [ type => 'label', label => '']};
		}
	}
	push @ret, { test_id => $reply->{line} };
	push @ret, { name => 'test_path',value => "$result->{TestDir}", attributes => [ type => 'hidden'] };
	push @ret, { action => 'cancel' };
	push @ret, { action => 'realy_delete' };
	return \@ret;
}

sub realy_delete
{
	my $this   = shift;
	my $reply  = shift;

	system("rm -r $reply->{test_path}");
	my $sth = $this->{DBH}->prepare("DELETE FROM TestWizardFiles WHERE TestId=\"$reply->{test_id}\";"); $sth->execute;
	$sth = $this->{DBH}->prepare("DELETE FROM TestWizardUsers WHERE TestId=\"$reply->{test_id}\";"); $sth->execute;
	$sth = $this->{DBH}->prepare("DELETE FROM TestWizard WHERE Id=\"$reply->{test_id}\";");	$sth->execute;
        $this->default();
}

sub test_continue
{
	my $this   = shift;
	my $reply  = shift;
	my $test_info_h = $this->get_test_info($reply->{line});
        my $start_test_room = $test_info_h->{TestRoom};
        my $act_room_name = main::GetSessionValue('room');

	if($act_room_name eq $start_test_room){
		my $current_step = $test_info_h->{CurrentStep};
		$reply->{test_id} = $reply->{line};
		$reply->{act_room_dn} = $reply->{tests}->{$reply->{line}}->{act_room_dn};
		$this->$current_step($reply);
	}else{
		return [
			{ NOTICE => sprintf(main::__('If you are not logged in the same classroom where you have started the exam, currently you cant continue. You can only continue the exam in "%s" classroom!'), $start_test_room).'<BR>'.main::__('If you wish to finish the exam please check that the results were corrected from the students!') },
			{ name => "line", value => "$reply->{line}", attributes => [ type => 'hidden'] },
			{ test_id => "$reply->{line}" },
			{ action => 'cancel' },
			{ action => 'open_test_info' },
			{ action => 'close' },
		];
	}
}

sub test_close
{
	my $this   = shift;
	my $reply  = shift;

	my $sth = $this->{DBH}->prepare("SELECT TestName FROM TestWizard WHERE Id=\'$reply->{line}\'");
	$sth->execute;
	my $result = $sth->fetchrow_hashref();

	return [
		{ subtitle => sprintf(main::__('Do you wish to close the "%s" test?'), $result->{TestName}) },
		{ NOTICE => main::__('If you wish to finish the exam please check that the results were corrected from the students!') },
		{ test_id => "$reply->{line}" },
		{ action => 'cancel' },
		{ action => 'open_test_info' },
		{ action => 'close' },
	]
}

sub close
{
	my $this   = shift;
	my $reply  = shift;
	my $TimeZones = getTimeZones();
	my( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst )   = localtime(time);
	my $end_time = sprintf('%4d-%02d-%02d %02d:%02d',$year+1900,$mon+1,$mday,$hour,$min);
	my $sth = $this->{DBH}->prepare("UPDATE TestWizard SET EndTime=\'$end_time\' WHERE Id=\"$reply->{test_id}\""); $sth->execute;
	$this->set_current_step( $reply, "" );
	return $this->default();
}

sub open_test_info
{
	my $this    = shift;
	my $reply   = shift;
	my $test_id = $reply->{line} || $reply->{test_id};
	my $hash = $this->get_test_info($test_id);
	my @ret;

	push @ret, { test_id   => "$test_id" };
	push @ret, { subtitle => "$hash->{TestName} "."test_info"};
	if( exists($hash->{TestRoom}) ){
		push @ret, { label => "<B>".main::__("start_test_room_name")."</B>" };
		push @ret, { name => 'room_name', value => "$hash->{TestRoom}", attributes => [ type => 'label', label => ""]};
	}
	if( exists($hash->{TestDir}) ){
		push @ret, { label => "<B>".main::__("test_directory")."</B>" };
		push @ret, { name => 'test_directory', value => "$hash->{TestDir}", attributes => [ type => 'label', label => ""]};
	}
	if( exists($hash->{StartTime}) ){
		push @ret, { label => "<B>".main::__("start_time")."</B>" };
		push @ret, { name => 'start_time', value => "$hash->{StartTime}", attributes => [ type => 'label', label => ""]};
	}
	if( exists($hash->{EndTime}) ){
		push @ret, { label => "<B>".main::__("close_time")."</B>" };
		push @ret, { name => 'close_time', value => "$hash->{EndTime}", attributes => [ type => 'label', label => ""]};
	}else{
		push @ret, { label => "<B>".main::__("close_time")."</B>" };
		push @ret, { name => 'close_time', value => main::__("not_close"), attributes => [ type => 'label',label => '', style => "color:red" ]};
	}
	if( exists($hash->{TestUserList}) ){
		my @user_list = ('test_user_list');
		push @ret, { label => "<B>".main::__("test_user_list")."</B>" };
		foreach my $id ( keys %{$hash->{TestUserList}}){
			push @user_list, { line => [ "test_user_list",
							{ pc_name => "$hash->{TestUserList}->{$id}->{PcName}" },
							{ user => "$hash->{TestUserList}->{$id}->{UserUID}" },
							{ user_name => "$hash->{TestUserList}->{$id}->{UserName}" },
							{ name => 'text_field', value => "$hash->{TestUserList}->{$id}->{Student}", attributes => [ type => 'label']},
				]};
		}
		push @ret, { table => \@user_list};
		push @ret, { name => 'download_this_list'  , value => main::__("download"), "attributes" => [ type => 'action', label => '' ] };
	}
	if( exists($hash->{Post}) ){
		my @send = ('send_files');
		push @ret, { label => "<B>".main::__("send_file")."</B>" };
		foreach my $user (keys %{$hash->{Post}}){
			$user =~ /^(.*)\((.*)\)/;
			my $user_t = $1.'( '.main::__("$2").' )';
			my $dir = join("<BR>",@{$hash->{Post}->{$user}});
			push @send, { line => [ "send_file",
							{name => 'user', value => "$user_t", attributes => [ type => 'label']},
							{name => 's_file', value => "$dir", attributes => [ type => 'label']},
				]};
		}
		push @ret, { table => \@send};
	}
	if( exists($hash->{Get}) ){
		push @ret, { label => "<B>".main::__("get_file")."</B>" };
		my @get = ('get_files');
		foreach my $user (keys %{$hash->{Get}}){
			$user =~ /^(.*)\((.*)\)/;
			my $user_t = $1.'( '.main::__("$2").' )';
			my $dir = join("<BR>",@{$hash->{Get}->{$user}});
			push @get, { line => [ "get_file",
							{name => 'user', value => "$user_t", attributes => [ type => 'label']},
							{name => 'g_file', value => "$dir", attributes => [ type => 'label']},
				]};
		}
		push @ret, { table => \@get};
	}

	return \@ret;
}

sub create_new_test
{
	my $this   = shift;
	my $reply  = shift;
	my @ret;
#	$reply->{act_room_dn} = "cn=Room2,cn=172.16.0.0,cn=config1,cn=schooladmin,ou=DHCP,dc=EXTIS-School55,dc=org";

	if( !$reply->{act_room_dn} ){
		return [
			{ NOTICE => main::__('A client should sing into a pc in a classroom so he can use this module!')}
		];
	}

	if( exists($reply->{warning}) ){
		push @ret, { NOTICE => $reply->{warning}};
	}

	my $room_name = $this->get_attribute($reply->{act_room_dn},'description');
	push @ret, { subtitle => "$room_name" };
	push @ret, { name => 'new_test_name', value => '', attributes => [ type => 'string', backlabel => "_test" ]};
	push @ret, { action => 'step0' };
	push @ret, { act_room_dn => $reply->{act_room_dn} };
	return \@ret;
}

sub step0
{
	my $this   = shift;
	my $reply  = shift;

	my $warning = '';
	if( !$reply->{new_test_name} ){
		$warning .= main::__('Please give the test a name!');
	}else{
		$reply->{new_test_name} =~ s/ /_/g;
		$reply->{new_test_name} =~ s/\./_/g;
	}

	my $act_test_dir = $this->get_attribute(main::GetSessionValue('dn'),'homeDirectory')."/Import/".$reply->{new_test_name}."_test/";
	my $user_uid = $this->get_attribute(main::GetSessionValue('dn'),'uid');
	my $sth = $this->{DBH}->prepare("SELECT Id FROM TestWizard WHERE TestName=\'$reply->{new_test_name}\' and ExaminerTeacher=\"$user_uid\"");
	$sth->execute;
	my $result = $sth->fetchrow_hashref();
	if($result->{Id}){
		$warning .= sprintf(main::__('The test called "%s" already exists'), $reply->{new_test_name});
	}else{
		system("mkdir -p $act_test_dir");
	}

	if($warning){
		$reply->{warning} = $warning;
		return $this->create_new_test($reply);
	}

        my $TimeZones = getTimeZones();
        my( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst )   = localtime(time);
	my $test_room = $this->get_attribute($reply->{act_room_dn}, 'description');
	my $start_time = sprintf('%4d-%02d-%02d %02d:%02d',$year+1900,$mon+1,$mday,$hour,$min);
	my ( $all, $mail, $print, $proxy, $samba ) = $this->get_room_access_state($reply->{act_room_dn});

	$sth = $this->{DBH}->prepare("INSERT INTO TestWizard (Id, TestName, ExaminerTeacher, TestRoom, TestDir, CurrentStep, StartTime, EndTime, WindowsAccess, ProxyAccess, DirectInternetAccess ) VALUES (NULL, \"$reply->{new_test_name}\", \"$user_uid\", \"$test_room\", \"$act_test_dir\", \"\", \"$start_time\", \"\", \"$samba\", \"$proxy\", \"$all\");");
	$sth->execute;
	$sth = $this->{DBH}->prepare("SELECT Id FROM TestWizard WHERE TestName=\'$reply->{new_test_name}\' and ExaminerTeacher=\"$user_uid\"");
	$sth->execute;
	$result = $sth->fetchrow_hashref();

	$reply->{test_id} = "$result->{Id}";
	$this->step1($reply);
}

sub step1 
{
	my $this   = shift;
        my $reply  = shift;

	$this->set_current_step( $reply, "step1" );
        $this->show($reply->{act_room_dn}, "step1", $reply->{test_id});
}

sub step2
{
	my $this   = shift;
	my $reply  = shift;

	$this->set_current_step( $reply, "step2" );
	$this->show($reply->{act_room_dn}, "step2", $reply->{test_id});
}

sub step3
{
        my $this   = shift;
        my $reply  = shift;
	my @ret;
	my $actuale_room_dn = $reply->{act_room_dn};
	my $room_name = $this->get_attribute($actuale_room_dn,'description');
	$this->set_current_step( $reply, "step3" );

	push @ret, { subtitle => "$room_name"};
	my $notice = main::__("Step 3:<BR>");
	$notice .= main::__("For tests which do not require Internet access, disable the internet access now using the button \"Disable Internet Access\".<BR>");
	$notice .= main::__("Press \"Disable Windows Login\" to disable the possibility for students to login with their own userid and password.");
	push @ret, { NOTICE => "$notice" };

	my ($int_enable_disable, $win_enable_disable, $proxy_color, $samba_color) = $this->get_int_winlog_access("$actuale_room_dn");
	my @lines = ('internet_windows_access');
	push @lines, { head => ['', '' ]};
	push @lines, { line => [ "internet_windows_access",
					{ name => 'en_dis_internet', value => $int_enable_disable, attributes => [ type => 'action', style => "color:".$proxy_color] },
					{ name => 'en_dis_windowslogin', value => "$win_enable_disable", attributes => [ type => 'action', style => "color:".$samba_color] },
					{ act_room_dn => "$actuale_room_dn" },
					{ name => 'step', value => "step3", attributes => [ type => 'hidden']},
					{ test_id   => "$reply->{test_id}" },
			]};
	push @ret, { table => \@lines };
	push @ret, { act_room_dn => "$actuale_room_dn" };
	push @ret, { test_id   => "$reply->{test_id}" };
	push @ret, { actual_page => 'step3' };
	push @ret, { action => "back" };
	push @ret, { action => 'step4' };
	return \@ret;
}

sub step4
{
        my $this   = shift;
        my $reply  = shift;
	my $actuale_room_dn = $reply->{act_room_dn};
	my @users = ();
	my @ret;
	my $room_name = $this->get_attribute($actuale_room_dn,'description');
	$this->set_current_step( $reply, "step4" );

	my $uid    = get_name_of_dn($this->{aDN});
        my $path   = $reply->{path} || $this->get_attribute($this->{aDN},'homeDirectory');
        if( $uid eq 'Administrator' )
        {
                $uid='admin';
        }
        my $dirs = cmd_pipe("/usr/share/oss/tools/print_dir.pl","uid $uid\npath $path");

	my @users_tmp = ();
	system("/usr/share/oss/tools/clean-up-sambaUserWorkstations.pl");
	my $logged_users = $this->get_logged_users("$actuale_room_dn");
	my $act_user = $this->get_attribute(main::GetSessionValue('dn'),"uid");
	foreach my $dn (sort keys %{$logged_users} ){
		if( (exists($logged_users->{$dn}->{user_name})) and ("$logged_users->{$dn}->{user_name}" ne "$act_user" ) ){
			push @users_tmp, $logged_users->{$dn}->{user_name}."(".$this->get_attribute($this->get_user_dn("$logged_users->{$dn}->{user_name}"), 'role').")";
		}
	}

	push @users, @users_tmp;
	push @users, '---DEFAULTS---';
	push @users, @users_tmp;

	my $notice = main::__("Step 4:<BR>");
	$notice .= main::__("You can now send files to the students. You can use the \"post_it\" button more than once to send more than one file. Press continue to start the test.");

	push @ret, { subtitle => "$room_name"};
	push @ret, { NOTICE => "$notice"};
	if(exists($reply->{error})){
		push @ret, { ERROR => "$reply->{error}"};
	}
	if(exists($reply->{warning})){
		push @ret, { NOTICE => "$reply->{warning}"};
	}
	push   @ret, { path          => $dirs };
	push   @ret, { file          => '' };
	push   @ret, { users         => \@users };
	push   @ret, { clear_import  => 1 };
	push   @ret, { actual_page   => 'step4' };
	push   @ret, { action        => "back" };
	push   @ret, { action        => "post_it" };
	push   @ret, { act_room_dn   => "$actuale_room_dn" };
	push   @ret, { action        => 'step5' };
	push   @ret, { test_id       => "$reply->{test_id}" };
	return \@ret;
}

sub step5
{
        my $this   = shift;
        my $reply  = shift;

	$this->set_current_step( $reply, "step5" );
	$this->show($reply->{act_room_dn}, "step5", $reply->{test_id});
}

sub step6
{
        my $this   = shift;
        my $reply  = shift;
	my $actuale_room_dn = $reply->{act_room_dn};
	my @ret;
	my @users = ();
	my $room_name = $this->get_attribute($actuale_room_dn,'description');

	if($reply->{actual_page} eq "step5"){
		$this->save($reply);
	}

	my @users_tmp;
	system("/usr/share/oss/tools/clean-up-sambaUserWorkstations.pl");
	my $logged_users = $this->get_logged_users("$actuale_room_dn");
	my $act_user = $this->get_attribute(main::GetSessionValue('dn'),"uid");
	foreach my $dn (sort keys %{$logged_users} ){
		if( (exists($logged_users->{$dn}->{user_name})) and ("$logged_users->{$dn}->{user_name}" ne "$act_user" ) ){
			push @users_tmp, $logged_users->{$dn}->{user_name}."(".$this->get_attribute($this->get_user_dn("$logged_users->{$dn}->{user_name}"), 'role').")";
                }
        }

	push @users, @users_tmp;
	push @users, '---DEFAULTS---';
	push @users, @users_tmp;
	$this->set_current_step( $reply, "step6" );

	my $notice  = main::__("Step 6:<BR>");
	$notice .= main::__("Now collect the fieles from the students. You will find the files in the import subdirectory of your homedirectory. If you enter something in \"withsubdir\" then, all files are stored in this subdirectory.");

	push @ret, { subtitle => "$room_name"};
	push @ret, { NOTICE => "$notice"};
	if(exists($reply->{warning})){
		push @ret, { NOTICE => "$reply->{warning}"};
	}
	push   @ret, { users         => \@users };
	push   @ret, { withsubdir    => "" };
	push   @ret, { clear_export  => 1 };
	push   @ret, { actual_page   => 'step6' };
	push   @ret, { action        => "back" };
	push   @ret, { action        => "get_it" };
	push   @ret, { act_room_dn   => "$actuale_room_dn" };
	push   @ret, { action        => 'step7' };
	push   @ret, { test_id       => "$reply->{test_id}" };
	return \@ret;
}

sub step7
{
	my $this   = shift;
	my $reply  = shift;
	my $actuale_room_dn = $reply->{act_room_dn};
	my $test_info_h = $this->get_test_info($reply->{test_id});

	my $ip = main::GetSessionValue('ip');
	$this->set_room_access_state( $actuale_room_dn, 'proxy', "$test_info_h->{ProxyAccess}", $ip );
	$this->set_room_access_state( $actuale_room_dn, 'samba', "$test_info_h->{WindowsAccess}", $ip );
	$this->set_room_access_state( $actuale_room_dn, 'all', "$test_info_h->{DirectInternetAccess}", $ip );

	my $TimeZones = getTimeZones();
	my( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst )   = localtime(time);
	my $end_time = sprintf('%4d-%02d-%02d %02d:%02d',$year+1900,$mon+1,$mday,$hour,$min);
	my $sth = $this->{DBH}->prepare("UPDATE TestWizard SET EndTime=\'$end_time\' WHERE Id=\"$reply->{test_id}\"");$sth->execute;
	$this->set_current_step( $reply, "" );

	return $this->default();
}

sub back
{
	my $this   = shift;
	my $reply  = shift;

	if($reply->{actual_page} eq "step2"){
		$this->step1($reply);
	}elsif($reply->{actual_page} eq "step3"){
		$this->step2($reply);
	}elsif($reply->{actual_page} eq "step4"){
		$this->step3($reply);
	}elsif($reply->{actual_page} eq "step5"){
		$this->step4($reply);
	}elsif(($reply->{actual_page} eq "step6") or ($reply->{actual_page} eq "get_it")){
		$this->step5($reply);
	}
}

sub refresh
{
	my $this   = shift;
	my $reply  = shift;

	system("/usr/share/oss/tools/clean-up-sambaUserWorkstations.pl");
	if($reply->{actual_page} eq "step1" ){
		$this->step1( $reply );
	}elsif( $reply->{actual_page} eq "step2" ){
		$this->step2( $reply );
	}
}

sub en_dis_internet
{
	my $this   = shift;
	my $reply  = shift;
	my $actuale_room_dn = $reply->{internet_windows_access}->{internet_windows_access}->{act_room_dn};
	my $step = $reply->{internet_windows_access}->{internet_windows_access}->{step};
	my $ip = main::GetSessionValue('ip');

	my ( $all, $mail, $print, $proxy, $samba ) = $this->get_room_access_state($actuale_room_dn);
	if( $proxy ){
		$this->set_room_access_state( $actuale_room_dn, 'proxy', "0", $ip );
		$this->set_room_access_state( $actuale_room_dn, 'all', "0", $ip );
	}else{
		$this->set_room_access_state( $actuale_room_dn, 'proxy', "1", $ip );
	}
	$reply->{act_room_dn} = $actuale_room_dn;
	$reply->{test_id} = $reply->{internet_windows_access}->{internet_windows_access}->{test_id};

	if( $step eq "step3"){
		$this->step3($reply);
	}else{
		$this->step5($reply);
	}
}

sub en_dis_windowslogin
{
	my $this   = shift;
	my $reply  = shift;
	my $actuale_room_dn = $reply->{internet_windows_access}->{internet_windows_access}->{act_room_dn};
	my $step = $reply->{internet_windows_access}->{internet_windows_access}->{step};
	my $ip = main::GetSessionValue('ip');

	my ( $all, $mail, $print, $proxy, $samba ) = $this->get_room_access_state($actuale_room_dn);
	if( $samba ){
		$this->set_room_access_state( $actuale_room_dn, 'samba', "0", $ip );
	}else{
		$this->set_room_access_state( $actuale_room_dn, 'samba', "1", $ip );
	}
	$reply->{act_room_dn} = $actuale_room_dn;
	$reply->{test_id} = $reply->{internet_windows_access}->{internet_windows_access}->{test_id};

	if( $step eq "step3"){
		$this->step3($reply);
	}else{
		$this->step5($reply);
	}
}

sub download_this_list
{
	my $this = shift;
	my $reply = shift;
	my $csv_file = "PcName;UserUID;UserName;Student\n";
	my $test_info_h = $this->get_test_info($reply->{test_id});

	foreach my $id ( keys %{$test_info_h->{TestUserList}} )
	{
		$csv_file .= $test_info_h->{TestUserList}->{$id}->{PcName}.";";
		$csv_file .= $test_info_h->{TestUserList}->{$id}->{UserUID}.";";
		$csv_file .= $test_info_h->{TestUserList}->{$id}->{UserName}.";";
		$csv_file .= $test_info_h->{TestUserList}->{$id}->{Student}."\n";
	}

	return [
		{ name => 'download' , value => encode_base64($csv_file), attributes => [ type => 'download', filename => "$test_info_h->{TestName}_TestUserList.csv", mimetype => 'text/plain' ] }
	];
}

sub get_int_winlog_access
{
	my $this = shift;
	my $actuale_room_dn = shift;
	my @get_int_winlog_access;

	my ( $all, $mail, $print, $proxy, $samba ) = $this->get_room_access_state($actuale_room_dn);
	my ($int_enable_disable, $win_enable_disable, $proxy_color, $samba_color) = '';
	if( $proxy ){
		$int_enable_disable = main::__("Disable Internet Access");
		$proxy_color = "green";
	}else{ 
		$int_enable_disable = main::__("Enable Internet Access");
		$proxy_color = "red";
	}
	if($samba){
		$win_enable_disable = main::__("Disable Windows Login");
		$samba_color = "green";
	}else{
		$win_enable_disable = main::__("Enable Windows Login");
		$samba_color = "red";
	}

	return $int_enable_disable, $win_enable_disable, $proxy_color, $samba_color;
}

sub save
{
	my $this   = shift;
	my $reply  = shift;

	foreach my $dn (sort keys %{$reply->{logon_user}} ){
		my $sth = $this->{DBH}->prepare("SELECT Id FROM TestWizardUsers WHERE TestId=\'$reply->{test_id}\' and PcName=\"$reply->{logon_user}->{$dn}->{pc_name}\" ");
		$sth->execute;
		my $result = $sth->fetchrow_hashref();
		if( $result->{Id} ){
			$sth = $this->{DBH}->prepare("UPDATE TestWizardUsers SET Student=\'$reply->{logon_user}->{$dn}->{text_field}\' WHERE Id=\"$result->{Id}\"");
		}else{
			$sth = $this->{DBH}->prepare("INSERT INTO TestWizardUsers (Id, TestId, PcName, UserUID, UserName, Student ) VALUES (NULL, \"$reply->{test_id}\", \"$reply->{logon_user}->{$dn}->{pc_name}\", \"$reply->{logon_user}->{$dn}->{user}\", \"$reply->{logon_user}->{$dn}->{user_name}\", \"$reply->{logon_user}->{$dn}->{text_field}\" );");
		}
		$sth->execute;
	}

	$this->step5($reply);
}

sub get_text_field
{
	my $this   = shift;
	my $test_id = shift;
	my $sth = $this->{DBH}->prepare("SELECT Id, TestId, PcName, UserUID, UserName, Student FROM TestWizardUsers WHERE TestId=\'$test_id\'");
	$sth->execute;  
	my $result = $sth->fetchall_hashref('Id');

	my %hash;
	foreach my $id ( keys %{$result}){
		$hash{$result->{$id}->{PcName}} = $result->{$id}->{Student};
	}
	return \%hash;
}

sub post_it
{
	my $this   = shift;
	my $reply  = shift;
	my $file   = $reply->{path};
	my $TimeZones = getTimeZones();
	my( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst )   = localtime(time);
	my $datetime = sprintf('%4d-%02d-%02d %02d:%02d',$year+1900,$mon+1,$mday,$hour,$min);
	my @users_tmp  = split /\n/, $reply->{users};
	my @users = ();

	if( defined $reply->{file}->{content} )
	{
		$file   = '/tmp/'.$reply->{file}->{filename};
		my $tmp = write_tmp_file($reply->{file}->{content});
		system("/usr/bin/base64 -d $tmp >'$file'; rm $tmp;");
	}

	if( ! -e $file )
	{
		$reply->{error} = main::__('Please choose a file');
		return $this->step3($reply);
	}

	foreach my $name (@users_tmp)
	{
		if( defined $reply->{file}->{content} ){
			my $sth = $this->{DBH}->prepare("INSERT INTO TestWizardFiles (Id, TestId, GetOrPost, User, File, DateTime ) VALUES (NULL, \"$reply->{test_id}\", \"post\", \"$name\", \"$reply->{file}->{filename}\", \"$datetime\" );"); $sth->execute;
		}else{
			my $pth = `ls -Rp $reply->{path}*`;
			my @splt_pth = split("\n\n",$pth);
			foreach my $gr ( @splt_pth ){
				my @splt_gr = split("\n",$gr);
				my $dir = shift(@splt_gr);
				chomp($dir); $dir =~ s/:/\//;
				foreach my $line (@splt_gr){
					chomp($line); if($line =~ /^(.*)\/$/){next}
					my $sth = $this->{DBH}->prepare("INSERT INTO TestWizardFiles (Id, TestId, GetOrPost, User, File, DateTime ) VALUES (NULL, \"$reply->{test_id}\", \"post\", \"$name\", \"$line\", \"$datetime\" );"); $sth->execute;
				}
			}
		}
		$name =~ /^(.*)\((.*)\)$/;
		my $dn = $this->get_user_dn("$1");
		push @users,  $dn;
	}

	$this->post_file($file,\@users,$reply->{clear_import},$reply->{clear_home});
	if( defined $reply->{file}->{content} )
	{
		unlink $file;
	}
	my @mess = ();
	foreach my $dn (@users)
	{
		push @mess, $this->get_attribute($dn,'cn');
	}
	$file  =~ s#^/tmp/##;

	$reply->{warning} = main::__("Sending file :").$file.". ".main::__("The users for whom we have sent the files/libraries :").join("; ",@mess);
	$this->step4($reply);
}

sub get_it
{
	my $this   = shift;
	my $reply  = shift;
	my $TimeZones = getTimeZones();
	my( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst )   = localtime(time);
	my $datetime = sprintf('%4d-%02d-%02d %02d:%02d',$year+1900,$mon+1,$mday,$hour,$min);
	my @users_tmp  = split /\n/, $reply->{users};
	my @users = ();
	my $sth = $this->{DBH}->prepare("SELECT TestDir FROM TestWizard WHERE Id=\'$reply->{test_id}\'"); $sth->execute;
	my $result = $sth->fetchrow_hashref();
	my $test_dir = "$result->{TestDir}$reply->{withsubdir}/";

	foreach my $name (@users_tmp)
	{
                $name =~ /^(.*)\((.*)\)$/;
		my $dn = $this->get_user_dn("$1");
		push @users,  $dn;
	}

	$result->{TestDir} =~ /^\/(.*)\/Import\/(.*)\//;
	my $withsubdir = $2;
	if($reply->{withsubdir}){
		$reply->{withsubdir} = $withsubdir."/".$reply->{withsubdir};
	}else{
		$reply->{withsubdir} = $withsubdir;
	}
	$this->collect_file(\@users,$reply->{clear_export},$reply->{sort_dir},$reply->{withsubdir});

	foreach my $name (@users_tmp)
        {
		$name =~ /^(.*)\((.*)\)$/;
		my $get_file = `ls $test_dir$1-*`;
		$get_file =~ s/\/\//\//;
		chomp($get_file);
		my @get_files = split( '\n', $get_file );
		foreach my $line ( sort @get_files ){
			$sth = $this->{DBH}->prepare("INSERT INTO TestWizardFiles (Id, TestId, GetOrPost, User, File, DateTime ) VALUES (NULL, \"$reply->{test_id}\", \"get\", \"$name\", \"$line\", \"$datetime\" );"); $sth->execute;
		}
        }

	my @mess = ();
	foreach my $dn (@users)
	{
		push @mess, $this->get_attribute($dn,'cn');
	}

	$reply->{users} = \@users_tmp;
	$reply->{actual_page} = 'get_it';
	$reply->{warning} = main::__("We have collected files from the following users :").join("; ",@mess);
	$this->step6($reply);
}

sub show
{
	my $this = shift;
	my $actuale_room_dn = shift;
	my $step = shift;
	my $test_id = shift;
	my @lines = ('logon_user');

	if( $step eq 'step5' ){push @lines, { head => [ 'pc_name', 'user', 'user_name', 'text_field'] } }
	my @ret;
	my $room_name = $this->get_attribute($actuale_room_dn,'description');

	system("/usr/share/oss/tools/clean-up-sambaUserWorkstations.pl");
	my $logged_users = $this->get_logged_users("$actuale_room_dn");
	foreach my $dn (sort keys %{$logged_users} )
	{
		if($step eq "step5"){
			my $text_field = $this->get_text_field($test_id);
			my $text_field_val = $text_field->{$logged_users->{$dn}->{host_name}};
			push @lines, { line => [ $dn,
					{ pc_name => "$logged_users->{$dn}->{host_name}" },
					{ user => "$logged_users->{$dn}->{user_name}" },
					{ user_name => "$logged_users->{$dn}->{user_cn}" },
					{ text_field => "$text_field_val" },
					{ name => 'pc_name', value => "$logged_users->{$dn}->{host_name}", attributes => [ type => 'hidden'] },
					{ name => 'user', value => "$logged_users->{$dn}->{user_name}", attributes => [ type => 'hidden'] },
					{ name => 'user_name', value => "$logged_users->{$dn}->{user_cn}", attributes => [ type => 'hidden'] },
			]};
		}else{
			push @lines, { line => [ $dn,
						{ pc_name => "$logged_users->{$dn}->{host_name}" },
						{ user => "$logged_users->{$dn}->{user_name}" },
						{ user_name => "$logged_users->{$dn}->{user_cn}" },
					]};
		}
	}

	if($step eq "step1"){
		my $notice = main::__("Step 1:<BR>");
		$notice .= main::__("If you want to write a test with anonymous logins, then ask now the students to logoff from their workstations. You can see in the displayed list all currently logged in students. Press \"refresh\" to check again. Press \"continue\" to go on.");
		push @ret, { subtitle => "$room_name"};
		push @ret, { NOTICE => "$notice" };
		push @ret, { table       => \@lines };
		push @ret, { act_room_dn => "$actuale_room_dn" };
		push @ret, { test_id     => "$test_id" };
		push @ret, { actual_page => 'step1' };
		push @ret, { action      => 'refresh' };
		push @ret, { action      => 'step2' };
		return \@ret;
	}elsif($step eq "step2"){
		my $pcs = $this->get_workstations_of_room($actuale_room_dn);
		my @pcs = sort(@$pcs);
		my $one_pc_name = $this->get_attribute($pcs[0],'cn');
		my $notice = main::__("Step 2:<BR>");
		$notice .= sprintf( main::__('For tests with anonymous logins: now all the students should login in with the workstation accounts. The workstation accounts loginname and password is the name of the workstation, e.g. userid: "%s" and password: "%s".'),$one_pc_name, $one_pc_name);
		push @ret, { subtitle => "$room_name"};
		push @ret, { NOTICE => "$notice" };
		push @ret, { table       => \@lines };
		push @ret, { act_room_dn => "$actuale_room_dn" };
		push @ret, { test_id     => "$test_id" };
		push @ret, { actual_page => 'step2' };
		push @ret, { action      => 'back' };
		push @ret, { action      => 'refresh' };
		push @ret, { action      => 'step3' };
		return \@ret;
	}elsif($step eq "step5"){
		my ($int_enable_disable, $win_enable_disable, $proxy_color, $samba_color) = $this->get_int_winlog_access("$actuale_room_dn");
		my @in_win_access = ('internet_windows_access');
		push @in_win_access, { head => ['', '' ]};
		push @in_win_access, { line => [ "internet_windows_access",
							{ name => 'en_dis_internet', value => $int_enable_disable, attributes => [ type => 'action', style => "color:".$proxy_color] },
							{ name => 'en_dis_windowslogin', value => "$win_enable_disable", attributes => [ type => 'action', style => "color:".$samba_color] },
							{ act_room_dn => "$actuale_room_dn" },
							{ test_id   => "$test_id" },
				]};
		my $notice = main::__("Step 5:<BR>");
		$notice .= main::__("Now let the students write their test. If the test is finished, press \"Continue\".<BR>");
		$notice .= main::__("If a pc crashes, then you can allow the windows login for this pc temporarily.<BR>");
#		$notice .= sprintf( main::__("If you write an anonymous test, you can now write down which student is working on which PC. This list is stored a file in your home directory named: %s"), $test_name) ;
		$notice .= main::__("If you write an anonymous test, you can now write down which student is working on which PC. This list can view or download on the 'Testassistent -> Test Informationen' page.");
		push @ret, { subtitle => "$room_name"};
		push @ret, { NOTICE => "$notice" };
		my $test_info_h = $this->get_test_info($test_id);
		push @ret, { name => 'date_time', value => "$test_info_h->{StartTime}", attributes => [type => 'label', label => main::__("Start Test : ")]};
		push @ret, { table       => \@in_win_access };
		push @ret, { table       => \@lines };
		push @ret, { act_room_dn => "$actuale_room_dn" };
		push @ret, { test_id     => "$test_id" };
		push @ret, { actual_page => 'step5' };
		push @ret, { action      => 'back' };
		push @ret, { action      => 'save' };
		push @ret, { action      => 'step6' };
		return \@ret;
	}
}

sub set_current_step
{
        my $this  = shift;
        my $reply = shift;
        my $step  = shift;
	my $sth = $this->{DBH}->prepare("UPDATE TestWizard SET CurrentStep=\'$step\' WHERE Id=\"$reply->{test_id}\"");
	$sth->execute;
}

sub get_test_info
{
	my $this    = shift;
	my $test_id = shift;
	my %hash;

	#get TestWizard
	my $sth = $this->{DBH}->prepare("SELECT Id, TestName, ExaminerTeacher, TestRoom, TestDir, CurrentStep, StartTime, EndTime, WindowsAccess, ProxyAccess, DirectInternetAccess FROM TestWizard WHERE Id=\'$test_id\'"); $sth->execute;
	my $result = $sth->fetchrow_hashref();
	foreach my $item ( keys %{$result} ){
		if( (($item eq 'StartTime') or ($item eq 'EndTime')) and ($result->{$item} ne '0000-00-00 00:00:00') ){
			my $language =  main::GetSessionValue('lang');
			my @dt = split( " ", $result->{$item} );
			my $date_time = date_format_convert("$language","$dt[0]");
			my @time = split( ":", $dt[1] );
			$hash{$item} = "$date_time $time[0]:$time[1]"; 
		}
		elsif( ($result->{$item}) and ( $result->{$item} ne '0000-00-00 00:00:00') ){
			$hash{$item} = $result->{$item};
		}
	}

	#get TestWizardFiles
	$sth = $this->{DBH}->prepare("SELECT Id, TestId, GetOrPost, User, File, DateTime FROM TestWizardFiles WHERE TestId=\'$test_id\'"); $sth->execute;
	$result = $sth->fetchall_hashref('Id');
	foreach my $id (sort keys %{$result} ){
		my @dt = split( " ", $result->{$id}->{DateTime} );
		my @time = split( ":", $dt[1] );
		my $d_time = "$time[0]:$time[1]";
		if($result->{$id}->{GetOrPost} eq 'post'){
			push @{$hash{Post}->{$result->{$id}->{User}}}, $result->{$id}->{File}." ( $d_time )";
		}elsif($result->{$id}->{GetOrPost} eq 'get'){
			push @{$hash{Get}->{$result->{$id}->{User}}}, $result->{$id}->{File}." ( $d_time )";
		}
	}

	#get TestWizardUsers
	$sth = $this->{DBH}->prepare("SELECT Id, TestId, PcName, UserUID, UserName, Student FROM TestWizardUsers WHERE TestId=\'$test_id\'"); $sth->execute;
	$result = $sth->fetchall_hashref('Id');
	foreach my $id (sort keys %{$result} ){
		$hash{TestUserList}->{$id} = $result->{$id};
	}

	return \%hash;
}

1;
