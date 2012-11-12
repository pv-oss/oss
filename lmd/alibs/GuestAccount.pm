# OSS LMD GuestAcount module
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package GuestAccount;

use strict;
use oss_base;
use oss_group;
use oss_user;
use oss_utils;
use Net::LDAP;
use oss_LDAPAttributes;
use Data::Dumper;
use Date::Parse;
use POSIX 'strftime';

use vars qw(@ISA);
@ISA = qw(oss_group);

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    $connect->{withIMAP} = 1;
    my $self    = oss_base->new($connect);
    return bless $self, $this;
}

sub interface
{
        return [
                "getCapabilities",
                "default",
		"addNewGuestGroup",
		"apply",
		"delete"
        ];
}

sub getCapabilities
{
        return [
                { title        => 'Guest Acount' },
                { type         => 'command' },
                { allowedRole  => 'root' },
                { allowedRole  => 'sysadmins' },
                { allowedRole  => 'teachers,sysadmins' },
                { allowedRole  => 'teachers' },
                { category     => 'User' },
                { order        => 60 },
                { variable     => [ "generalpassword",     [ type => "string" ] ] },
		{ variable     => [ "accountsnumber",      [ type => "string" ] ] },
		{ variable     => [ 'roomlist',            [ type => 'list', size =>'5', multiple => 'true' ] ]},
		{ variable     => [ "expirationdategroup", [ type => "date", label => 'ExpirationDateGroup'] ] },
		{ variable     => [ "grouptype",           [ type => "hidden"] ] },
		{ variable     => [ "fquota",              [ type => "string", label => "fquota", backlabel => "MB" ] ] },
		{ variable     => [ "privategroup",        [ type => "boolean" ] ] },
		{ variable     => [ "webdav_access",       [ type => "boolean" ] ] },
		{ variable     => [ "delete",              [ type => "action" ] ] },
        ];
}

sub default
{
	my $this = shift;
	my @r =();
	my @lines =('guestgroups');
	my $language =  main::GetSessionValue('lang');

	my $mydn = main::GetSessionValue('dn');
	my $dn = $this->get_current_guestgroups($mydn);

	for(my $i = 0; $i < scalar(@$dn); $i++ ){
                my $group = $this->get_group(@$dn[$i]);
		my $accountnmb = $group->{member};
		my $accountsnumber = scalar(@$accountnmb);
		
		my $privategroup;
		if($group->{writerdn}->[0]){
			$privategroup = main::__('Yes');
		}else{
			$privategroup = main::__('No');}
		
		my $expirationdategroup = $this->get_vendor_object( @$dn[$i], 'EXTIS','ExpirationDateGroup');
		$expirationdategroup->[0] = date_format_convert("$language","$expirationdategroup->[0]");

		my $webdav_access = $this->get_vendor_object( @$dn[$i], 'EXTIS','WebDavAccess');
		if($webdav_access->[0]){
			$webdav_access = main::__("Yes");
		}else{
			$webdav_access = main::__("No");
		}
		my $roomlist = $this->get_vendor_object( @$dn[$i], 'EXTIS','RoomList');
			
		my @line = ( @$dn[$i] );
		push @line, { name => 'name', value => $group->{cn}->[0], "attributes" => [ type => "label" ] };
		push @line, { name => 'description', value => $group->{description}->[0], "attributes" => [ type => "label" ] };
		push @line, { name => 'privategroup', value => $privategroup, "attributes" => [ type => "label" ] };
		push @line, { name => 'webdav_access', value => $webdav_access, "attributes" => [ type => "label" ] };
		push @line, { name => 'accountsnumber', value => $accountsnumber-1, "attributes" => [ type => "label" ] };
		push @line, { name => 'ExpirationDateGroup', value => $expirationdategroup->[0], "attributes" => [ type => "label" ] };
		push @line, { name => 'RoomList', value => main::__("$roomlist->[0]"), "attributes" => [ type => "label" ] };
		push @line, { delete => main::__('delete')};
		push @lines, { line => \@line};

        }

	push @r, { table => \@lines};
	push @r, { action => 'addNewGuestGroup' } ;
	return \@r;
}

sub addNewGuestGroup
{
	my $this  = shift;
	my $tmp   = $this->get_rooms();
	my @rooms = ();
	my @newgroup = ();
	my $reply = shift;
	my $error = shift || '';

	if($error ne ''){
		push @newgroup, { ERROR => $error};
	}
	my $cn = $reply->{cn} || '';
	my $description = $reply->{description} || '';
	my $generalpassword = $reply->{generalpassword} || '';
	my $accountsnumber = $reply->{accountsnumber} || '';
	my $fquota = $reply->{fquota} || '';
	my $privategroup = $reply->{privategroup} || '';

	my( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst )   = localtime(time);
        my $Date = sprintf('%4d-%02d-%02d',$year+1900,$mon+1,$mday);
	my @time = strptime($Date);
	$time[3] = $time[3]+6;
	my $expirationdate = POSIX::strftime("%Y-%m-%d", @time);

	foreach my $dn (sort keys %{$tmp})
        {
		push @rooms, $tmp->{$dn}->{"description"}->[0];
        }

	push @newgroup, { cn => $cn };
	push @newgroup, { description => $description };
        push @newgroup, { generalpassword => $generalpassword };
        push @newgroup, { accountsnumber => $accountsnumber } ;
	push @newgroup, { fquota => $fquota };
	push @newgroup, { expirationdategroup => $expirationdate};
	push @newgroup, { roomlist => [ 'all', @rooms ] } ;
	push @newgroup, { grouptype => 'guest'};
	push @newgroup, { privategroup => $privategroup };
	push @newgroup, { webdav_access => 0 } ;
	push @newgroup, { action => 'cancel' } ;
        push @newgroup, { action => 'apply' } ;

	return \@newgroup;
}

sub apply
{
	my $this  = shift;
	my $reply = shift;
	my @roomlist = ();
	my @pcs;	
	my $pclist;

	my @error;
	my $errors = '';
	if(!$reply->{cn}){
		push @error, 'Assign group name';
	}
	if(!$reply->{generalpassword}){
		push @error, 'Assign password';
	}
	if(!$reply->{accountsnumber}){
		push @error, 'Enter the number of users';
	}
	if(!$reply->{fquota}){
                push @error, 'Enter the size of storage users';
        }
	if(!$reply->{roomlist}){
		push @error, 'Assign classroom(s) which can be accessed by the users';
	}
	
	$errors = join ",<br>", @error;
	if( $errors ne '' ){
		return $this->addNewGuestGroup($reply,$errors);
	}

	my( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst )   = localtime(time);
        my $DateNow = sprintf('%4d-%02d-%02d',$year+1900,$mon+1,$mday);

	if( $DateNow le $reply->{expirationdategroup} ){

		# create group
		my %GROUP = ();
		$GROUP{cn} = uc($reply->{cn});
	        $GROUP{description} = $reply->{description};
		$GROUP{grouptype} = 'guest';
		$GROUP{role} = lc($reply->{cn});

		my $oss_group = oss_group->new();
		my $dng = $oss_group->add(\%GROUP);
	        if( !$dng )
	        {
	           return {
	                TYPE    => 'ERROR',
	                CODE    => $oss_group->{ERROR}->{code},
	                MESSAGE_NOTRANSLATE => $oss_group->{ERROR}->{text}
	           }
	        }

		$this->create_vendor_object($dng,'EXTIS','ExpirationDateGroup', "$reply->{expirationdategroup}" );
                if($reply->{privategroup} == 1){
                        $this->{LDAP}->modify( $dng, add => { writerDN => main::GetSessionValue('dn') } );
                }

		$this->make_delete_group_webdavshare( "$dng", "$reply->{webdav_access}" );
	
	       if( $reply->{roomlist} ne 'all' ){
	               $this->create_vendor_object($dng,'EXTIS','RoomList', $reply->{roomlist} );
	               foreach my $r ( split /\n/, $reply->{roomlist} ) {
	                        foreach my $dn ( @{$this->get_workstations_of_room($r)} ){
	                                push @pcs, $this->get_attribute($dn,'cn');
	                        }      
	                }      
	        }elsif( $reply->{roomlist} eq 'all' ){
	                $this->create_vendor_object($dng,'EXTIS','RoomList', 'all' );
	        }      
	
		#create users
		for( my $i = 1; $i <= $reply->{accountsnumber}; $i++ ){
			my %USER =();
			$USER{role} = lc($reply->{cn});
			$USER{uid}  = lc($reply->{cn}).''.sprintf("%02i",$i);
			$USER{sn}   = $USER{uid};
			my @workgroup = ("$GROUP{cn}");
			$USER{group} = \@workgroup;
			$USER{userpassword} = $reply->{generalpassword};
			$USER{fquota} = $reply->{fquota};
	
			my $oss_user = oss_user->new();
	                my $dnu =$oss_user->add(\%USER);
	
	        	if( !$dnu ){
	        	   return {
	                	TYPE    => 'ERROR',
	       	         	CODE    => $oss_user->{ERROR}->{code},
	                	MESSAGE_NOTRANSLATE => $oss_user->{ERROR}->{text}
		           }
		        }

			if( scalar @pcs ) {
			        $this->{LDAP}->modify( $dnu, add => { sambaUserWorkstations => join(" ", @pcs) } );
			}
			if($reply->{privategroup} == 1){
	               		$this->{LDAP}->modify( $dnu, add => { writerDN => main::GetSessionValue('dn') } );
		       	}

		}

		#create at
		my $cmd = "at 23:59 $reply->{expirationdategroup}";
                my $arg = "/usr/share/oss/setup/delete-guest-".uc($reply->{cn}).".pl";
                my $tmp = cmd_pipe("$cmd", "$arg");

                # create /usr/share/oss/setup/delete-guest-<GroupName>.pl script
                my $deletescripturl = "/usr/share/oss/setup/delete-guest-".uc($reply->{cn}).".pl";
                open(FILE,"\> $deletescripturl") or die "Can't open $deletescripturl !\n";
                my $deleteguestscript = "#!/usr/bin/perl\n\nBEGIN{ push".' @INC,"/usr/share/oss/lib/";'." }\n\nuse strict;\nuse oss_group;\nuse oss_base;\nuse oss_user;\nuse oss_utils;\nuse vars qw(".'@ISA'.");\n".'@ISA'." = qw(oss_group);\n\n";
                $deleteguestscript .= "my ".'$base'." = oss_base->new();\nmy ".'@group'." = (\"$dng\");\nmy ".'$users =$base'."->search_users(\"*\",".'\@group'.");\n\nforeach my ".'$dnu (keys  %$users'."){\n   ".'my $connect->{withIMAP} = 1;'."\n   ".'my $user = oss_user->new($connect);'."\n   ".'$user->delete("$dnu");'."\n}\n\n";
                $deleteguestscript .= "my ".'$this'." = shift;\nmy ".'$connect'." = shift || undef;\n".'$connect'."->{withIMAP} = 1;\nmy ".'$group'." = oss_group->new(".'$connect'.");\n\n".'$group->delete("'.$dng.'");'."\n\n";

		my $contact = $this->get_attribute(main::GetSessionValue('dn'),'cn');
		my $mailto = $this->get_attribute(main::GetSessionValue('dn'),'mail');
		my $MAIL = 'SUBJECT="Delete one group an users"\'."\n".\'CONTACT="'.$contact.'"\'."\n".\'MAILFROM="admin@EXTIS-School.org"\'."\n".\'MAILTO="'.$mailto.'"';
		my $TEXT = 'Delete in the '.uc($reply->{cn}).' Group and users';

		$deleteguestscript .= 'system(\'echo Delete in the '.uc($reply->{cn}).' Group and users|mail -s OSS: Delete one group an users -r admin@EXTIS-School.org '.$mailto.'\');'."\n";

		$deleteguestscript .= 'system(\'rm -r /etc/apache2/vhosts.d/oss-ssl/'.uc($reply->{cn}).".conf');\n";
                $deleteguestscript .= "system('rmdir /home/".lc($reply->{cn})."');\n";
                $deleteguestscript .= "system(\"unlink ".'/usr/share/oss/setup/delete-guest-'.uc($reply->{cn}).'.pl")';


                printf FILE $deleteguestscript;
                close (FILE);
                chmod(0755, $deletescripturl );


		$this->default();
	}else{
		$errors = 'The given expirationdategroup\'s value is older than todays date. Please add a future date';
		return $this->addNewGuestGroup($reply,$errors);
	}

}

sub delete
{
        my $this   = shift;
        my $reply  = shift;
	my $cn     = $this->get_attribute($reply->{line},'cn');
	my $dn     = $reply->{line};

        if( ! $dn )
        {
                return { TYPE    => 'ERROR',
                         MESSAGE => ''
                };
        }

	my @group = ($dn);
        my $users =$this->search_users('*',\@group);

        my $connect->{withIMAP} = 1;
        my $user = oss_user->new($connect);
        foreach my $dnu (keys  %$users){
                if( !$user->delete("$dnu"))
                {
                        return {
                                TYPE => 'ERROR',
                                MESSAGE => $user->{ERROR}->{text}
                        }
                }
        }
	$user->destroy();

	$this->make_delete_group_webdavshare( "$dn", "0" );
        my $group = oss_group->new($connect);
        if( !$group->delete($dn))
        {
                return {
                        TYPE => 'ERROR',
                        MESSAGE => $group->{ERROR}->{text}
                }
        }
	$group->destroy();
	if ( -d '/home/'.lc($cn) && lc($cn) ne '' ){
		system( 'rmdir /home/'.lc($cn) );
	}
	system('rm /usr/share/oss/setup/delete-guest-'.uc($cn).'.pl');
        $this->default();
}

#-----------------------------------------------------------------------
# Private finctions
#-----------------------------------------------------------------------

sub get_current_guestgroups
{
    my $this        = shift;
    my $writerDN    = shift;
    my $school_base = shift || $this->{LDAP_BASE};
    $school_base    = $this->get_school_base($school_base);
    my @dn          = ();

    my $filter      = '(&(objectClass=SchoolGroup)(groupType=guest)(|(writerDN='.$writerDN.')(!(writerDN=*))))';;

    my $mesg = $this->{LDAP}->search( base   => 'ou=group,'.$school_base,
                                      filter => $filter,
                                      scope  => 'one',
                                      attrs  => [ 'dn' ]
                                    );
    foreach my $entry ( $mesg->entries() )
    {
      push @dn, $entry->dn();
    }
    return \@dn;
}

1;
