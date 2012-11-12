# LMD ImportUser module
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ImportUser;

use strict;
use oss_user;
use oss_utils;
use oss_LDAPAttributes;
use MIME::Base64;
use Data::Dumper;
use Encode;
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
                "import",
                "showOldImports",
		"open",
		"delete",
		"create_letters",
		"create_pdf",
		"next",
		"back",
		"my_cancel",
		"refresh",
        ];

}

sub getCapabilities
{
        return [
                { title        => 'Import List of User' },
                { type         => 'command' },
                { allowedRole  => 'root' },
                { allowedRole  => 'sysadmins' },
                { allowedRole  => 'teachers,sysadmins' },
                { category     => 'User' },
		{ order        => 30 },
                { variable     => [ "mustchange",      [ type => "boolean" ] ] },
                { variable     => [ "full",            [ type => "boolean" , label=>"This list contains all user" ] ] },
                { variable     => [ "test",            [ type => "boolean" , label=>"Try only what would happen"] ] },
                { variable     => [ "alias",           [ type => "boolean" ] ] },
                { variable     => [ "mailenabled",     [ type => "popup" ] ] },
		{ variable     => [ "role",            [ type => "popup" ] ] },
		{ variable     => [ "format",          [ type => "popup" ] ] },
		{ variable     => [ "lang",            [ type => "popup", label=>"File Header Language" ] ] },
		{ variable     => [ "file",            [ type => "filefield" ] ] },
		{ variable     => [ "path_file",       [ type => 'hidden'] ] },
		{ variable     => [ "pg_limit",        [ type => 'hidden'] ] },
		{ variable     => [ "imp_dat_subtit",  [ type => 'hidden'] ] },
	];
}

sub default
{
	my $this    = shift;

	#-- lets see if import is running
	if( -e "/var/run/import_user.pid" )
	{
		my $file_info;
		my $file = '';
		foreach my $f ( sort ( glob "/home/groups/SYSADMINS/import.*.log" ) )
                {
			$file = $f;
			$file_info = $this->get_file_info("$f");
                }
		my @lines = ('import_files');
		push @lines, { head => [ "import_date_time", "import_test", "open", "", "" ] };
		push @lines, { line => [ $file,
                                        { name => 'import_date_time', value => "$file_info->{date_time}", attributes => [ type => 'label', help => "$file_info->{import_param}"] },
                                        { name => 'import_test', value => "$file_info->{test_import}", attributes => [ type => 'label' ] },
                                        { name => 'open', value => main::__('open'), attributes => [ type => 'action' ] },
					{ name => 'start_import_open', value => '1', attributes => [ type => 'hidden' ] },
                                        { imp_dat_subtit => "$file_info->{date_time}" },
                        ]};
		return [
			{ NOTICE => 'The import of the user was started'},
			{ table => \@lines },
		]
	}
        my @role    = ( );
	my @format = ( 'CSV' );
        my ( $primaries, $classes, $workgroups ) = $this->get_school_groups_to_search();
        foreach my $i ( @{$primaries} )
        {
            my $dn  = shift @{$i};
            my $des = shift @{$i};
	    my $r   = $this->get_attribute($dn,'role');
	    next if ( $r eq 'templates' || $r eq 'workstations' );
            push @role, [ $r, $des ]; 
        }
	push @role, '---DEFAULTS---', 'students';
	foreach ( glob("/usr/share/oss/tools/ConvertImport*") )
	{
		/\/usr\/share\/oss\/tools\/ConvertImport(.*).pl/;
		push @format, $1;
	}
	push @format, '---DEFAULTS---', $this->{SYSCONFIG}->{SCHOOL_IMPORT_FILE_FORMAT};

	my @mailenabled = ([ 'ok', main::__('ok') ],  [ 'no', main::__('no') ], [ 'local_only', main::__('local_only') ] );
	my $default_mailenabled = $this->get_school_config('SCHOOL_MAILBOX_ACCESS') || 'ok';
	push @mailenabled, '---DEFAULTS---', "$default_mailenabled" ;

        return [
                { file         => '' },
		{ format       => \@format },
                { role         => \@role},
		{ lang         => getLanguages(main::GetSessionValue('lang')) },
		{ test	       => 1 },
		{ full	       => 0 },
		{ alias	       => 0 },
		{ mustchange   => 0 },
		{ userpassword => '' },
		{ mailenabled  => \@mailenabled },
                { action       => "cancel" },
                { action       => "showOldImports" },
                { action       => "import" }
        ];

}

sub import
{
	my $this     = shift;
	my $reply    = shift;
	write_file('/tmp/userlist.row',$reply->{file}->{content});
	system('base64 -d /tmp/userlist.row > /tmp/userlist.in');

	if(!RecodeImportFile('/tmp/userlist.in'))
	{
		return { TYPE    => 'ERROR',
			 CODE    => 'BAD_IMPORT_FILE',
			 MESSAGE => 'The import file can not be converted into UTF-8'
		};
	}

	if($reply->{format} ne 'CSV' )
	{
		if(!ConvertImportFile('/tmp/userlist.in',$reply->{format}))
		{
			return { TYPE    => 'ERROR',
				 CODE    => 'BAD_IMPORT_FILE',
				 MESSAGE => 'The import file can not convert to CSV'
			};
		}
	}
	else
	{
		system('cp /tmp/userlist.in /tmp/userlist.txt');
	}

	my $attributes = '--sessionID '.$reply->{SESSIONID}.' --role '.$reply->{role}.' --mailenabled '.$reply->{mailenabled};
	if( $reply->{role} eq 'students' && $reply->{full} )
	{
		$attributes .= ' --full';
	}
	if( $reply->{mustchange} )
	{
		$attributes .= ' --mustchange';
	}
	if( ! $reply->{test} )
	{
		$attributes .= ' --notest';
	}
	if( $reply->{alias} )
	{
		$attributes .= ' --alias';
	}
	if( $reply->{userpassword} ne '' )
	{
		$attributes .= " --userpassword '".$reply->{userpassword}."'";
	}
	if( $reply->{lang} ne '' )
	{
		$attributes .= " --lang '".$reply->{lang}."'";
	}
	my $admun_user_name = main::GetSessionValue('username');
	$attributes .= " --admin '".$admun_user_name."'";
	main::Debug("Import Started with attributes: $attributes\n");
	system("PERL_UNICODE='' /usr/sbin/oss_import_user_list.pl $attributes &");
	return { TYPE    => 'NOTICE',
		 CODE    => 'IMPORT_STARTED',
		 MESSAGE => 'The import of the user was started'
	};
}

sub showOldImports
{
	my $this     = shift;
	my $reply    = shift;
	my $admin_used = main::GetSessionValue('username');
	my @lines = ('import_files');
	my @ret;

	push @lines, { head => [ "import_date_time", "import_test", "open", "delete", "create_letters" ] };
	foreach my $f ( sort ( glob "/home/groups/SYSADMINS/import.*.log" ) )
	{
		my $file_info = $this->get_file_info("$f");
		my @line ;
		push @line, $f;
		push @line, { name => 'import_date_time', value => "$file_info->{date_time}", attributes => [ type => 'label', help => "$file_info->{import_param}"] };
		push @line, { name => 'import_test', value => "$file_info->{test_import}", attributes => [ type => 'label' ] };
		push @line, { name => 'open', value => main::__('open'), attributes => [ type => 'action' ] };
		push @line, { name => 'delete', value => main::__("delete"), attributes => [ type => 'action' ] };
		if($file_info->{create_letters}){
			push @line, { name => 'create_letters', value => main::__('create_letters'), attributes => [ type => 'action'] };
		}
		push @line, { imp_dat_subtit => "$file_info->{date_time}" };
		push @lines, { 'line' => \@line };
	}

	push @ret, { table  => \@lines };
	push @ret, { action => "cancel" };
	return \@ret;
}

sub open
{
	my $this        = shift;
	my $reply       = shift;
	my $import_file = $reply->{line};
	my $pg_num      = $reply->{pg_num} || 0;
	my $pg_limit    = $reply->{pg_limit} || 20;
	my $pg_init     = 0;
	my @list        = ('import_list');
	my @del_user    = ('del_users');
	my @mess        = ('message');
	my @ret;

	push @ret, { subtitle => $reply->{import_files}->{$reply->{line}}->{imp_dat_subtit} };

	my $hash = $this->get_import_list("$import_file");
	foreach my $index (sort keys %{$hash}){
	if( $pg_init == $pg_limit){
			last;
		}elsif( $pg_init < $pg_num ){
			$pg_init++;
			next;
		}else{
			if( $hash->{$index}->{unknown_attr_header} ){
				push @ret, { label => main::__("Warning:") };
				push @ret, { line     => [ "unkn_attr" , { name => "mess", value => "$hash->{$index}->{unknown_attr_header}", attributes => [type => 'label'] } ] };
				$pg_init++;
			}
			if($hash->{$index}->{new_user}){
				push @list, { line => [ 'list',
							{ name => "givenname", value => "$hash->{$index}->{new_user}->{givenname}", attributes => [ type => "label"] },
							{ name => "sn", value => "$hash->{$index}->{new_user}->{sn}", attributes => [ type => "label"] },
							{ name => "birthday", value => "$hash->{$index}->{new_user}->{birthday}", attributes => [ type => "label"] },
							{ name => "messages", value => "$hash->{$index}->{new_user}->{messages}", attributes => [ type => "label"] },
				]};
				$pg_init++;
			}
			if($hash->{$index}->{del_user}){
				push @del_user, { line => [ 'del_user', 
							{ name => "uid", value => "$hash->{$index}->{del_user}->{uid}", attributes => [ type => "label"] },
							{ name => "message", value => "$hash->{$index}->{del_user}->{message}", attributes => [ type => "label"] },
						]};
				$pg_init++;
			}
			if($hash->{$index}->{syncingdb}){
				push @mess, { head => [ "" ]};
				push @mess, { line => [ "mess" , 
							{ name => "mess", value => "$hash->{$index}->{syncingdb}", attributes => [type => 'label'] },
						]};
				$pg_init++;
			}
			if( $hash->{$index}->{close_on_error} ){
#				push @ret, { ERROR => "$hash->{$index}->{close_on_error}"};
				push @ret, { label => main::__("Warning:") };
				push @ret, { line     => [ "close_on_error" , { name => "mess", value => "$hash->{$index}->{close_on_error}", attributes => [type => 'label'] } ] };
				$pg_init++;
			}
		}
	}

	if( scalar(@list) > 2 ){
		push @ret, { label => main::__('Import Users :')};
		push @ret, { table     => \@list };
	}
	if( scalar(@del_user) > 2 ){
		push @ret, { label     => main::__('Delete Users :')};
		push @ret, { table     => \@del_user };
	}
	if( scalar(@mess) > 1){
		push @ret, { label => main::__("Message:") };
		push @ret, { table     => \@mess };
	}

	if(($pg_init < $pg_limit) and ($pg_init > $pg_num) and !$pg_num){

	}elsif(!$pg_num){
		push @ret, { rightaction    => 'next' };
	}elsif( ($pg_init < $pg_limit) and ($pg_init > $pg_num)  ){
		push @ret, { rightaction    => 'back' };
	}else{
		push @ret, { rightaction    => 'back' };
		push @ret, { rightaction    => 'next' };
	}

	if( exists($reply->{import_files}->{$reply->{line}}->{start_import_open}) ){
                push @ret, { rightaction => 'refresh' };
                push @ret, { name => 'start_import_open', value => '1', attributes => [ type => 'hidden' ] };
        }else{
		push @ret, { rightaction    => 'my_cancel' };
	}

	push @ret, { path_file => "$import_file" };
	push @ret, { pg_limit  => "$pg_limit" };
	push @ret, { imp_dat_subtit => "$reply->{import_files}->{$reply->{line}}->{imp_dat_subtit}"};
	return \@ret;
}

sub next
{
	my $this  = shift;
	my $reply = shift;

	$reply->{line}     = $reply->{path_file};
	$reply->{import_files}->{$reply->{line}}->{imp_dat_subtit} = $reply->{imp_dat_subtit};
	$reply->{pg_num}   = $reply->{pg_limit};
	$reply->{pg_limit} = $reply->{pg_num} + 20;
	$reply->{import_files}->{$reply->{line}}->{imp_dat_subtit} = $reply->{imp_dat_subtit};
	if( exists($reply->{start_import_open}) ){
		$reply->{import_files}->{$reply->{line}}->{start_import_open} = '1';
	}
	$this->open($reply);
}

sub back
{
	my $this  = shift;
	my $reply = shift;

	$reply->{line}     = $reply->{path_file};
	$reply->{import_files}->{$reply->{line}}->{imp_dat_subtit} = $reply->{imp_dat_subtit};
	$reply->{pg_num}   = $reply->{pg_limit} - 40;
	$reply->{pg_limit} = $reply->{pg_limit} - 20;
	if( exists($reply->{start_import_open}) ){
		$reply->{import_files}->{$reply->{line}}->{start_import_open} = '1';
	}
	$this->open($reply);
}

sub delete
{
	my $this  = shift;
	my $reply = shift;
	system("rm $reply->{line}");
	$reply->{line} =~ /^\/home\/groups\/SYSADMINS\/import\.(.*)\.log/;
	my $importpath_dir = "/home/groups/SYSADMINS/userimport.$1/";
	system("rm -r $importpath_dir");
        $this->showOldImports($reply);
}

sub my_cancel
{
        my $this  = shift;
        my $reply = shift;
        $this->showOldImports($reply);
}

sub refresh
{
	my $this  = shift;
	my $reply = shift;

	$reply->{line}     = $reply->{path_file};
        $reply->{import_files}->{$reply->{line}}->{imp_dat_subtit} = $reply->{imp_dat_subtit};
	$reply->{import_files}->{$reply->{line}}->{start_import_open} = '1';
	$reply->{pg_num}   = $reply->{pg_limit} - 20;
        $reply->{pg_limit} = $reply->{pg_limit} ;
	$this->open($reply);
}

sub create_letters
{
	my $this  = shift;
	my $reply = shift;
	my $lang = main::GetSessionValue('lang');
	my @ret;

	# subtitle
	my $import_date = $reply->{import_files}->{$reply->{line}}->{imp_dat_subtit};
	push @ret, { subtitle => "$import_date / ".main::__('Password Letters')};
	#notice
	push @ret, { NOTICE => main::__('Text for password letter generation')};
	#import date
	push @ret, { name => 'import_date', value => "$import_date", attributes => [ type => 'label', label => main::__('Password Letters for Import from :')] };
	#import class
	my $import_class = $this->get_import_class("$reply->{line}");
	if( !exists($import_class->{class}) ){
		return [
#			{ NOTICE => main::__('Missing userimport directory!')},
			{ NOTICE => sprintf(main::__('Missing the userimport.%s directory!'), $import_date) }
		]
	}

	push @ret, { name => 'import_class', value => [@{$import_class->{class}}, 'all', '---DEFAULTS---', 'all'], attributes => [ type => 'popup', label => main::__('Select Class to generate a letter :') ] };
	#text for letter
	my $text_letter = cmd_pipe("cat /usr/share/lmd/tools/JavaBirt/Reports/ImportUser_modul/letter_$lang.txt");
	$text_letter =~ s/,//g;
	push @ret, { name => 'text_letter', value => "$text_letter", attributes => [ type => 'text', label => main::__('Text on the letter :') ] };
	#store text
	push @ret, { name => 'store_text', value => 0, attributes => [ type => 'boolean', label => main::__('Store this text for later usage :') ] };
	push @ret, { name => 'imp_log_file', value => $reply->{line}, attributes => [ type => 'hidden' ] };
	#buttons
	push @ret, { action => 'create_pdf' };
	push @ret, { action => 'my_cancel' };


	return \@ret;
}

sub create_pdf
{
	my $this  = shift;
	my $reply = shift;
	my $tmp_csv_file = '/tmp/make_csv_file_for_leter.csv';
	my $report_url = '/usr/share/lmd/tools/JavaBirt/Reports/ImportUser_modul/UserPasswordLetters.rptdesign';
	my $lang = main::GetSessionValue('lang');

	if( $reply->{store_text} ){	
		write_file( "/usr/share/lmd/tools/JavaBirt/Reports/ImportUser_modul/letter_$lang.txt", $reply->{text_letter});
		my $file = "/usr/share/lmd/tools/JavaBirt/Reports/ImportUser_modul/letter_$lang.txt";
                my $format = `file -bi $file`;
                chomp $format; $format =~ /charset=(.*)/; $format = $1;
                if( $format eq 'unknown' ) {
                   $format  = 'iso-8859-1';
                }
                system("recode $format..utf8 $file");
	}

	$reply->{imp_log_file} =~ /^\/home\/groups\/SYSADMINS\/import\.(.*)\.log/;
	my $importpath_file = "/home/groups/SYSADMINS/userimport.$1/";
	if( $reply->{import_class} ne 'all' ){
		$importpath_file .= "userlist.$reply->{import_class}.txt";
	}

	if( ! (-e "$importpath_file")){
		return [
			{ NOTICE => sprintf(main::__('Missing the "%s" file (or directory)!'), $importpath_file) }
		]
	}

	my $new_file_content = '';
	if( $importpath_file =~ /^\/(.*)\/$/){
		my %hash;
		my %head_h;
		my $import_files = `ls $importpath_file*.txt`;

		my @files = split("\n", $import_files );
		my $head = `cat $files[0]`;
		my ($hd, @tmp) = split("\n", $head);
		my $sep = get_sep("$hd");
		my @head__ = split($sep, $hd);
		my $i = 0;
		my $user_login_pos;
		foreach my $item (@head__){
			$head_h{$i} = $item;
			$user_login_pos = $i if( $item eq "LOGIN" );
			$i++;
		}
		foreach my $file (@files){
			next if( $file !~ /(.*).txt$/);
			my $file_content = `cat $file`;
			my @splt_file_content = split("\n", $file_content);
			shift(@splt_file_content);
			foreach my $line (@splt_file_content){
				if( $line !~ /^ $/ ){
					my @sp_line = split($sep,$line);
					foreach my $it (keys %head_h){
						if( (exists($hash{$sp_line[$user_login_pos]}->{$head_h{$it}})) and ( $hash{$sp_line[$user_login_pos]}->{$head_h{$it}} ne $sp_line[$it]) ){
							$hash{$sp_line[$user_login_pos]}->{$head_h{$it}} .= " ".$sp_line[$it];
						}else{
							$hash{$sp_line[$user_login_pos]}->{$head_h{$it}} = $sp_line[$it];
						}
					}
				}
			}
		}

		foreach my $head_it (sort keys %head_h){
			$new_file_content .= $head_h{$head_it}.",";
		}
		my $class_ = uc(main::__('class'));
		if( $new_file_content !~ /(.*)$class_(.*)/){
			$new_file_content .= $class_.",";
		}
		$new_file_content .= "\n";

		foreach my $item (keys %hash){
			foreach my $head_it (sort keys %head_h){
				$new_file_content .= $hash{$item}->{$head_h{$head_it}}.",";
			}
			$new_file_content .= "\n";
		}

	}else{
		#One csv file:
		my $file_content = cmd_pipe("cat $importpath_file");
		my @splt_file_content = split("\n", $file_content);
		my $hd = shift @splt_file_content;
		my $sep = get_sep("$hd");
		$hd =~ s/$sep/,/g;
		$new_file_content .= $hd;
		my $class_ = uc(main::__('class'));
		if( $new_file_content !~ /(.*)$class_(.*)/){
			$new_file_content .= ",".$class_.",";
		}
		$new_file_content .= "\n";
		foreach my $line (@splt_file_content){
			if( $line !~ /^ $/ ){
				$line =~ s/$sep/,/g;
				$new_file_content .= $line."\n";
			}
		}
	}
	if( ! utf8::is_utf8($new_file_content) ){
		utf8::decode($new_file_content);
		utf8::encode($new_file_content);
	}
	write_file( $tmp_csv_file, $new_file_content);

	my $csv_file = `basename '$tmp_csv_file'`; chomp $csv_file;
	my $cmd = 'java -jar /usr/share/lmd/tools/JavaBirt/JavaBirt.jar REPORT_URL='.$report_url.' COMMAND=EXECUTE OUTPUT=pdf CSV_HOME_DIR=/tmp CSV_FILE='.$csv_file.' PASSWORD_LETTER_TEXT="'.$reply->{text_letter}.'"';

	my $result = cmd_pipe("$cmd");

	if($result){
		return [
			{ NOTICE => "$result" },
		]
	}

	$report_url =~ s/rptdesign/pdf/;
	my $mime = `file -b --mime-type '$report_url'`;  chomp $mime;
	my $tmp  = `mktemp /tmp/ossXXXXXXXX`;    chomp $tmp ;
	system("/usr/bin/base64 -w 0 '".$report_url."' > $tmp ");
	my $content = get_file($tmp);
	my $name    = `basename '$report_url'`; chomp $name;
	return [
		{ name=> 'download' , value=>$content, attributes => [ type => 'download', filename=>$name, mimetype=>$mime ] }
	];
}

sub get_sep
{
	my $hd       = shift;
	my $sep      = "";
	my $muster   = "";
	my @attr_ext = ();
	foreach my $attr (@userAttributes, @additionalUserAttributes)
	{
		$attr = lc($attr);
		my $name  = uc(main::__($attr));
		push @attr_ext, $name;
	}
	foreach my $i (sort @attr_ext){
		if( $i ne ""){
			$muster.="$i|";
		}
	}
	chomp $muster;
	$muster =~ s/\|$//;
	$muster =~ s/\///g;
	$muster =~ s/\(//g;
	$muster =~ s/\)//g;
	my $HEADER = uc($hd);
	$HEADER =~ s/^[^A-Z]//;
	$HEADER =~ /($muster)(.+?)($muster)/i;
	$sep = $2 if( defined $2 );
	return "$sep";
}

#-----------------------------------------------------------------------
sub ConvertImportFile($$) {
        my ($file, $format) = @_;
        my $rc = system("/usr/share/oss/tools/ConvertImport$format.pl --convert_import_file=$file");
	print STDERR "EXIT CODE OF Convert $?\n";

#        if($rc != 0){
#	   print STDERR "EXIT CODE OF Convert $rc\n";
#          system ("rm /tmp/userlist.txt");
#           return  0;
#        }

        return 1;
}
#-----------------------------------------------------------------------
sub RecodeImportFile($) {
	my $file   = shift;
        my $format = `file -bi $file`;
        chomp $format;
        $format =~ /charset=(.*)/;
        if( !defined $1 ) {
           return 0;
        }
        $format = $1;
        if( $format eq 'unknown' ) {
           $format  = 'iso-8859-1';
        }
        system("recode $format..utf8 $file");

        return 1;
}
#-----------------------------------------------------------------------
sub get_import_list
{
	my $this = shift;
	my $import_list_path = shift;
	my $counter = 1;
	my %hash;

	my $tmp = `cat $import_list_path`;
	if( ! utf8::is_utf8($tmp) ){
		utf8::decode($tmp);
		utf8::encode($tmp);
	}
	my @splt_tmp = split("---",$tmp);
	my $prm = shift(@splt_tmp);
	foreach my $sec (@splt_tmp){
		$counter = sprintf("%03d",$counter );
		if( $sec =~ /^user:(.*)/ ){
			my @splt_new_user = split("user: ",$sec);
			foreach my $user (@splt_new_user){
#                               print $user."======>user\n";
				my @lines = split("\n", $user);
				my ($givenname, $sn, $birthday, $messages) = "";
				foreach my $line (@lines){
					if( $line =~ /^givenname=(.*);sn=(.*);birthday=(.*)/){
						$givenname=$1; $sn=$2; $birthday=$3;
					}else{
						$messages .= "$line";
					}
				}
				$hash{$counter}->{new_user}->{givenname} = $givenname;
				$hash{$counter}->{new_user}->{sn} = $sn;
				$hash{$counter}->{new_user}->{birthday} = $birthday;
				$hash{$counter}->{new_user}->{messages} = $messages;
				$counter++;
			}
		}elsif( $sec =~ /^uid=(.*)/ ){
			my @splt_new_user = split("\n",$sec);
			foreach my $line (@splt_new_user){
				my ($uid, $messages) = split("#;#", $line);
				my ($uid_key, $uid_value) = split("=",$uid);
				my ($mess_key, $mess_value) = split("=",$messages);
				$hash{$counter}->{del_user}->{uid} = $uid_value;
				$hash{$counter}->{del_user}->{message} = $mess_value;
				$counter++;
			}
		}elsif( $sec =~ /^unknown_attr_header(.*)/ ){
			$hash{$counter}->{unknown_attr_header} = $1;
			$counter++;
		}elsif( $sec =~ /^syncingdb(.*)/ ){
			$hash{$counter}->{syncingdb} = $1;
			$counter++;
		}else{
			$hash{$counter}->{close_on_error} = $sec;
			$counter++;
		}
	}
#print Dumper(%hash)."--->hash\n";exit;	
	return \%hash;
}

sub get_file_info
{
	my $this  = shift;
	my $f = shift;
	my $language = main::GetSessionValue('lang');
	my %hash;

	$f   =~ /import\.(.*)\.(.*).log/;
	my $y = substr("$1", 0, 4);
	my $m = substr("$1", 5, 2);
	my $d = substr("$1", 8, 2);
	my $hour = substr("$2", 0, 2);
	my $min  = substr("$2", 3, 2);
	my $sec  = substr("$2", 6, 2);
	$hash{date_time} = "$d.$m.$y $hour:$min:$sec";
	if($language eq "HU"){
		$hash{date_time} = "$y.$m.$d $hour:$min:$sec";
	}
	my @file_name = split("/", $f);
	my $tmp = `cat $f`;
	my @splt_tmp = split("\n",$tmp);
	my $prm = shift(@splt_tmp);
	my @param = split(",",$prm);
	$hash{import_param} = '';
	$hash{test_import} = main::__('Real Import');
	$hash{create_letters} = 1;
	foreach my $i (@param){
		my ($key, $value) = split("=",$i);
		if( ($key eq "test") and ($value eq "0")){
			$hash{test_import} = main::__('Test Import');
			$value = main::__("Yes");
			$hash{create_letters} = 0;
		}elsif(($key eq "test") and ($value eq "1")){
			$value = main::__("No");
		}
		if($value eq 1){$value = main::__("Yes")}elsif($value eq 0){$value = main::__("No")}
		$hash{import_param} .= main::__("$key")."=".main::__("$value")."; ";
	}
	return \%hash;
}

sub get_import_class
{
	my $this = shift;
	my $import_file = shift;
	my %hash;

	$import_file =~ /^\/home\/groups\/SYSADMINS\/import\.(.*)\.log/;
	if( -e "/home/groups/SYSADMINS/userimport.$1/"){
		foreach my $f ( sort ( glob "/home/groups/SYSADMINS/userimport.$1/userlist.*.txt" ) )
		{
			$f =~ /(.*)\/userlist\.(.*)\.txt$/;
			push @{$hash{class}}, $2;
			push @{$hash{csv_files}}, $f;
		}
	}

	return \%hash;
}

1;
