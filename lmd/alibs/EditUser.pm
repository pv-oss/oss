# LMD EditUser modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package EditUser;

use strict;
use oss_user;
use oss_utils;
use oss_LDAPAttributes;
use MIME::Base64;
use Storable qw(thaw freeze);
use vars qw(@ISA);
@ISA = qw(oss_user);

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    $connect->{withIMAP} = 1;
    my $self    = oss_user->new($connect);
    $self->{RADIUS} = ($self->get_school_config('SCHOOL_USE_RADIUS') eq 'yes') ? 1 : 0;
    return bless $self, $this;
}

sub interface
{
	return [
                "changePassword",
                "changeQuota",
                "changeUserState",
                "default",
                "deleteRealy",
                "deleteUser",
		"deleteProfil",
                "editUser",
                "exportUser",
                "getCapabilities",
                "profil_ro",
                "profil_rw",
                "search",
                "searchAgain",
		"searchUsersFiles",
                "setChanges",
                "setPassword",
                "setProfil",
                "setProfilRealy",
                "setQuota",
                "setUserState",
		"showUser"
	];

}

sub getCapabilities
{
	my $this        = shift;
	my $name        = shift;
	my $title       = 'Edit User';
	my $category    = 'User';
	my $allowedRole = ['root','sysadmins','teachers,sysadmins'];
	my $order	= 20;

	if( $name eq 'ManageStudents' )
	{
		$title       = 'Manage Students';
		$category    = 'Students';
		$allowedRole = ['teachers','root','sysadmins','teachers,sysadmins'];
		$order       = 30;
	}
	return [
		{ title        => $title },
		{ category     => $category },
		{ type         => 'command' },
		{ allowedRole  => $allowedRole },
		{ order        => $order },
		{ variable     => [ "dn", 			[ type => "hidden" ] ] },
		{ variable     => [ "users",			[ type => "list", size=>"20", multiple=>"true" ] ] },
		{ variable     => [ "class",			[ type => "list", size=>"10", multiple=>"true" ] ] },
		{ variable     => [ "workgroup",		[ type => "list", size=>"10", multiple=>"true" ] ] },
		{ variable     => [ "role", 			[ type => "list", size=>"6",  multiple=>"true" ] ] },
		{ variable     => [ "rasaccess",                [ type => "list", size=>"5",  multiple=>"true" ] ] },
		{ variable     => [ "uid", 			[ type => "label"  ] ] },
		{ variable     => [ "label1", 			[ type => "label", label=>'', ] ] },
		{ variable     => [ "label2", 			[ type => "label", label=>'' ] ] },
		{ variable     => [ "sn", 			[ type => "label"  ] ] },
		{ variable     => [ "givenname", 		[ type => "label"  ] ] },
		{ variable     => [ "name", 			[ type => "string"  ] ] },
                { variable     => [ "mailenabled",              [ type => "translatedpopup",  ] ] },
                { variable     => [ "logindisabled",            [ type => "translatedpopup",  ] ] },
                { variable     => [ "internetdisabled",         [ type => "translatedpopup",  ] ] },
                { variable     => [ "oxenabled",                [ type => "translatedpopup",  ] ] },
		{ variable     => [ "sambauserworkstations",    [ type => "translatedpopup",  ] ] },
		{ variable     => [ "maynotchangepassword",     [ type => "translatedpopup" ] ] },
                { variable     => [ "admin",                    [ type => "boolean" ] ] },
                { variable     => [ "alias",                    [ type => "boolean" ] ] },
                { variable     => [ "mustchange",               [ type => "boolean" ] ] },
                { variable     => [ "birthday",                 [ type => "date",   ] ] },
                { variable     => [ "mail",                     [ type => "popup" ] ] },
                { variable     => [ "domains",                  [ type => "popup",  label=>'' ] ] },
                { variable     => [ "newsusemailacceptaddress", [ type => "string", label=>'' ] ] },
                { variable     => [ "preferredlanguage",        [ type => "popup" ] ] },
                { variable     => [ "fquota",                   [ type => "string", label => "fquota", backlabel => "MB" ] ] },
                { variable     => [ "quota",                    [ type => "string", label => "quota", backlabel => "MB" ] ] },
                { variable     => [ "fquotaused",               [ type => "string", label => "fquotaused", backlabel => "MB" ] ] },
                { variable     => [ "quotaused",                [ type => "string", label => "quotaused", backlabel => "MB" ] ] },
                { variable     => [ "oxtimezone",               [ type => "popup" ] ] },
                { variable     => [ "newgroup",			[ type => "list", size=>"5", multiple=>"true" ] ] },
                { variable     => [ "group",			[ type => "list", help => 'Select Entry to delete', size=>"5", multiple=>"true" ] ] },
                { variable     => [ "susemailforwardaddress",   [ type => "list", help => 'Select Entry to delete', size=>"5", multiple=>"true" ] ] },
                { variable     => [ "susemailacceptaddress",    [ type => "list", help => 'Select Entry to delete', size=>"5", multiple=>"true"] ] },
		{ variable     => [ "webdav_access",            [ type => "boolean" ] ] },
		{ variable     => [ "userpassword",             [ type => "password" ] ] },
#                { variable     => [ "susemailforwardaddress",   [ type => "list", label => "susemailforwardaddress", help => 'Select Entry to delete', size=>"5", multiple=>"true" ] ] },
#                { variable     => [ "susemailacceptaddress",    [ type => "list", label => "susemailacceptaddress",  help => 'Select Entry to delete', size=>"5", multiple=>"true"] ] }
	];
}

sub default
{
	my $this   = shift;
	my $reply  = shift;
	my $name    	= $reply->{name} || '*'; 
	my @ret    = ( { subtitle    => 'Search User' } );
	push @ret, { NOTICE => main::__("Please choose some filter criteria for searching your users.") };
	my ( $roles, $classes, $workgroups ) = $this->get_school_groups_to_search();
	if( $this->{LDAP_BASE} ne main::GetSessionValue('sdn') )
	{
	       push @ret, { label => main::__( 'Selected School: '). $this->get_attribute(main::GetSessionValue('sdn'),'o') };
	}
	push @ret, { name	      => $name };
	if( !$this->{ManageStudents} )
	{
		push @ret, { role        => $roles};
	}
	push @ret, { class       => $classes };
	push @ret, { workgroup   => $workgroups };
	push @ret, { rightaction => "search" };
	return \@ret;

}

sub search
{
	my $this   = shift;
	my $reply  = shift;
	my $name    	= $reply->{name} || '*'; 
	my @role        = split /\n/, $reply->{role}  || ();
	my @group       = split /\n/, $reply->{workgroup} || ();
	my @class       = split /\n/, $reply->{class} || ();
	my $fgroup	= undef;
	my $ngroup	= undef;
	my @users       = ();
	if( $this->{ManageStudents} )
	{
		@role = ($this->get_group_dn('students'));
		push @role, $this->get_group_dn('workstations');
	}
	my $user	= $this->search_users($name,\@class,\@group,\@role);

	foreach my $dn ( sort keys %{$user} )
	{
		push @users , [ $dn, $user->{$dn}->{uid}->[0].' '.$user->{$dn}->{cn}->[0].' ('.$user->{$dn}->{description}->[0].')' ];
	}
	push @users , '---DEFAULTS---';
	foreach my $dn ( sort keys %{$user} )
	{
		push @users , $dn;
	}

	if( $this->{ManageStudents} )
	{
		return [
			{ users	        => \@users },
			{ rightaction   => "changePassword" },
			{ rightaction   => "changeQuota" },
			{ rightaction   => "changeUserState" },
			{ rightaction   => "setProfil" },
			{ rightaction   => "showUser" },
			{ rightaction   => "exportUser" },
			{ rightaction   => "searchUsersFiles" },
			{ rightaction   => "searchAgain" }
		];
	}
	return [
		{ users	        => \@users },
		{ rightaction   => "changePassword" },
		{ rightaction   => "editUser" },
		{ rightaction   => "changeQuota" },
		{ rightaction   => "changeUserState" },
		{ rightaction   => "setProfil" },
		{ rightaction   => "deleteUser" },
		{ rightaction   => "exportUser" },
		{ rightaction   => "searchUsersFiles" },
		{ rightaction   => "searchAgain" }
	];
}

sub searchAgain
{
	my $this   = shift;
	my $reply  = shift;
	$this->default($reply);
}

sub noUser
{ #Internal
	return {
	     TYPE    => 'NOTICE',
	     CODE    => 'NO_USER_SELECTED',
	     MESSAGE => 'select_user'
	};
}

sub searchUsersFiles
{
       my $this   = shift;
       my $reply  = shift;
       my @users  = split /\n/, $reply->{users}; 
       return noUser() if( ! scalar @users );
       my $myuid  = main::GetSessionValue('username');

       my $list   = "";
        foreach my $dn ( @users )
       {
               $list .= $this->get_attribute($dn,'cn').', ';
               my $uid= $this->get_attribute($dn,'uid'); 
               cmd_pipe('at now', "/usr/share/oss/tools/find_files_of_user.sh $uid $myuid");
       }
       return [
               { subtitle    => 'Searching the files for following users was started:' },
               { notranslate_label       => $list },
               { label       => "The reports will be written in SearchUsersFiles in Your home directory." },
               { name => 'action', value => "cancel", attributes => [ label => 'back' ] }
       ];
}

sub changeQuota
{
	my $this   = shift;
	my $reply  = shift;
	my @users  = split /\n/, $reply->{users}; 
	return noUser() if( ! scalar @users );

	my $freeze = encode_base64(freeze(\@users),"");
	main::AddSessionDatas($freeze,'changeQuota');
	my $list   = "";
        foreach my $dn ( @users )
	{
		$list .= $this->get_attribute($dn,'cn').',';
	}
	return [
		{ subtitle    => 'Setting Quota for:' },
		{ notranslate_label       => $list },
		{ label       => "Leave the fields empty to make no changes!" },
		{ label       => "The value 0 means no quota." },
		{ quota       => "" },
		{ fquota      => "" },
		{ action      => "cancel" },
		{ name => 'action', value => "setQuota", attributes => [ label => 'apply' ] }
	];
}

sub setQuota
{
	my $this   = shift;
	my $reply  = shift;
	my $quota  = $reply->{quota}  eq "" ? undef : $reply->{quota};
	my $fquota = $reply->{fquota} eq "" ? undef : $reply->{fquota};
	my $freeze = decode_base64(main::GetSessionDatas('changeQuota'));
	my @users  = @{thaw($freeze )} if( defined $freeze );
        foreach my $dn ( @users )
	{
	    $this->set_fquota($dn,$fquota) if ( defined $fquota );
	    $this->set_quota($dn,$quota)   if ( defined $quota );
	}
	$this->default();
}

sub changePassword
{
	my $this   = shift;
	my $reply  = shift;
	my @users  = split /\n/, $reply->{users}; 
	return noUser() if( ! scalar @users );
	my @ret;

	my $freeze = encode_base64(freeze(\@users),"");
	main::AddSessionDatas($freeze,'changePassword');
	my $may_not_change_password = 0;
	my $list   = "";
        foreach my $dn ( @users )
	{
		my $u = $this->get_attributes($dn,[ 'cn','shadowmin','shadowmax' ] );
		if( defined $u->{shadowmin}->[0] && defined $u->{shadowmax}->[0] && ( $u->{shadowmin}->[0] > $u->{shadowmax}->[0] ) )
		{
			$may_not_change_password = 1;
		}
		$list .= $u->{cn}->[0].',';
	}

	push @ret, { subtitle     => "Setting New Password for:" };
	push @ret, { label        => $list };
	push @ret, { userpassword => "" };
	if( !$may_not_change_password ){
		push @ret, { mustchange   => 1 };
	}
	push @ret, { action       => "cancel" };
	push @ret, { name => 'action', value => "setPassword", attributes => [ label => 'apply' ] };
	return \@ret;
}

sub setPassword
{
	my $this   = shift;
	my $reply  = shift;
	my $freeze = decode_base64(main::GetSessionDatas('changePassword'));
	my @users  = @{thaw($freeze )} if( defined $freeze );
        foreach my $dn ( @users )
	{
		if( ! $this->set_password($dn,$reply->{userpassword},$reply->{mustchange},0,'smd5') )
		{
			return {
			     TYPE    => 'ERROR',
			     CODE    => $this->{ERROR}->{code},
			     MESSAGE_NOTRANSLATE => $this->{ERROR}->{text}
			};
		}
	}
	$this->default();
}

sub editUser
{
	my $this   = shift;
	my $reply  = shift;
	my @users  = split /\n/, $reply->{users}; 
	return noUser() if( ! scalar @users );

	my $dn     = $users[0];
	my @ret    = ();
	my $user   = $this->get_user($dn,\@userAttributeList);
	my @groups = ();
	my @newgr  = ();
	my $res    = $this->{LDAP}->search( base  => $this->{SYSCONFIG}->{GROUP_BASE},
				filter => "(&(!(groupType=primary))(!(member=$dn)))",
				scope  => 'one',
				attributes => ['description','cn']
				);
        my %groups = ();
        foreach my $e ( $res->entries )
        {
                my $d = $e->get_value('description') || $e->get_value('cn');
                $groups{$d} = $e->dn;
        }
        foreach my $d ( sort {uc($a) cmp uc($b)} keys %groups )
        {
                push @newgr, [ $groups{$d} , $d ];
        }
	foreach my $attr ( @userAttributeList )
	{
		next if( $attr eq 'rasaccess' && ! $this->{RADIUS} );
		next if( $attr eq 'role' );
		next if( $attr =~/^susemail.*address|mail$/ && $user->{mailenabled}->[0] =~ /no/i );
		my $val = undef;
		if( defined $user->{$attr} )
		{
			if( $attr =~ /^susemail.*address$/ )
			{
				$val =  $user->{$attr};
			}
			elsif( $attr eq 'preferredlanguage' )
			{
				$val =  getLanguages($user->{$attr}->[0]);
			}
			elsif( $attr eq 'oxtimezone' )
			{
				$val =  getTimeZones($user->{$attr}->[0]);
			}
			elsif( $attr eq 'c' )
			{
				next;
			}
			elsif( $attr eq 'group' )
			{
				foreach my $g (@{$user->{$attr}})
				{
					my $d = $this->get_attribute($g,'description') || $this->get_attribute($g,'cn');
					push @groups, [ $g , $d ];
				}
				$val = \@groups;
			}
			else
			{
				$val = join '', @{$user->{$attr}};
			}
		}
                if( $attr eq 'mail' )
                {
			next if ( ! defined $user->{susemailacceptaddress} );
                        my @tmp = ( @{$user->{susemailacceptaddress}} );
                        if ( defined $user->{$attr}->[0] )
                        {
                                push @tmp , '---DEFAULTS---' , $user->{$attr}->[0];
                        }
                        $val = \@tmp ;
                }
                if( $attr eq 'mailenabled' )
                {
                        my $mail = defined $user->{$attr}->[0] ? $user->{$attr}->[0] : 'ok';
                        $val = [ 'ok', 'local_only','NO', '---DEFAULTS---' , $mail ];
                }
		if( $attr eq 'rasaccess' )
		{
			my @rasaccess = ( @{$this->get_wlan_workstations} , '---DEFAULTS---' );
			if( defined $user->{$attr} )
			{
				push @rasaccess, @{$user->{$attr}};
			}
			else
			{
				push @rasaccess, 'no';
			}
			$val = \@rasaccess ;
		}
		push @ret, { $attr => $val };
		if( $attr =~ /^susemailacceptaddress$/ )
		{
			push @ret, { table => [ 'new' , { head => ['','','',''] } ,
						        { line => [ 'addr' , {label1 =>main::__('newsusemailacceptaddress') },
									     { newsusemailacceptaddress => '' },
									     {label2 =>'@'}, { domains => $this->get_mail_domains(1) }]}] };
		}
		if( $attr =~ /^susemailforwardaddress$/ )
		{
			push @ret, { newsusemailforwardaddress => '' };
		}
		if( $attr =~ /^group$/ )
		{
			push @ret, { newgroup => \@newgr };
		}
	}
	my $webdav_access_value = $this->get_vendor_object($dn,'EXTIS','WebDavAccess');
	push @ret, { webdav_access => "$webdav_access_value->[0]" };
	push @ret, { dn           => $dn };
	push @ret, { action       => "cancel" };
	push @ret, { name => 'action', value => "setChanges", attributes => [ label => 'apply' ]  };
	return \@ret;
}

sub setChanges
{
	my $this   = shift;
	my $reply  = shift;
	if( $reply->{new}->{addr}->{newsusemailacceptaddress} ne '' && defined $reply->{new}->{addr}->{domains} )
	{
		$reply->{newsusemailacceptaddress} = $reply->{new}->{addr}->{newsusemailacceptaddress}.'@'.$reply->{new}->{addr}->{domains};
	}
	delete $reply->{new};
	make_array_attributes($reply);
	if( ! $this->modify($reply) )
	{
		return {
		     TYPE    => 'ERROR',
		     CODE    => $this->{ERROR}->{code},
		     MESSAGE_NOTRANSLATE => $this->{ERROR}->{text}
		}
	}

	$this->editUser( { users => $reply->{dn}} );
}

sub changeUserState
{
	my $this   = shift;
	my $reply  = shift;
	my @users  = split /\n/, $reply->{users}; 
	return noUser() if( ! scalar @users );

	my $freeze = encode_base64(freeze(\@users),"");
	main::AddSessionDatas($freeze,'changeUserState');
	my @list   = ('state');
        foreach my $dn ( @users )
	{
		my $u = $this->get_attributes($dn,[ 'cn','mailenabled','logindisabled','internetdisabled','oxenabled','sambauserworkstations','shadowmin','shadowmax' ] );
		my $may_not_change_password = 'no';
		$u->{logindisabled}->[0]    = 'no'  if( ! defined $u->{logindisabled}->[0] );
		$u->{internetdisabled}->[0] = 'no'  if( ! defined $u->{internetdisabled}->[0] );
		$u->{oxenabled}->[0]        = 'no'  if( ! defined $u->{oxenabled}->[0] );
		$u->{shadowmin}->[0]        = 0     if( ! defined $u->{shadowmin}->[0] );
		$u->{shadowmax}->[0]        = 99999 if( ! defined $u->{shadowmin}->[0] );
		if( $u->{shadowmin}->[0] > $u->{shadowmax}->[0] )
		{
			$may_not_change_password = 'yes';
		}
		push @list, { line => [ $dn ,	{ name => 'cn',               value => $u->{cn}->[0],                                        attributes => [ type => 'label' ] }, 
						{ name => 'mailenabled',      value => main::__($u->{mailenabled}->[0]),                     attributes => [ type => 'label' ] },
						{ name => 'logindisabled',    value => main::__($disabledLabel{$u->{logindisabled}->[0]}),   attributes => [ type => 'label' ] },
						{ name => 'internetdisabled', value => main::__($disabledLabel{$u->{internetdisabled}->[0]}),attributes => [ type => 'label' ] },
						{ name => 'oxenabled',        value => main::__($enabledLabel{$u->{oxenabled}->[0]}),        attributes => [ type => 'label' ] },
						{ name => 'sambauserworkstations', value => $u->{sambauserworkstations}->[0],                attributes => [ type => 'label' ] },
						{ name => 'maynotchangepassword',value => main::__($disabledLabel{$may_not_change_password}),attributes => [ type => 'label' ] },]};
	}
	return [
		{ subtitle         => "Change the State for:" },
		{ table		   => \@list },
		{ label		   => '' },
		{ mailenabled      => \@mailEnabledChange },
		{ internetdisabled => \@disabledChange },
		{ logindisabled    =>  [ 'do_not_change', [ 'no', 'enabled' ], [ 'yes', 'disabled' ], '---DEFAULTS---', 'do_not_change' ] },
		{ oxenabled        => \@enabledChange },
		{ sambauserworkstations    =>  [ 'do_not_change', 'clean' , '---DEFAULTS---', 'do_not_change' ] },
		{ maynotchangepassword     =>  [ 'do_not_change', [ 'no', 'enabled' ], [ 'yes', 'disabled' ], '---DEFAULTS---', 'do_not_change'] },
		{ action           => "cancel" },
		{ name => 'action', value => "setUserState", attributes => [ label => 'apply' ] }
	];
}

sub setUserState
{
	my $this   = shift;
	my $reply  = shift;
	my $freeze = decode_base64(main::GetSessionDatas('changeUserState'));
	my @users  = @{thaw($freeze )} if( defined $freeze );
        foreach my $dn (@users)
        {
                if( $reply->{mailenabled} ne 'do_not_change' )
                {
                        $this->{LDAP}->modify( $dn, replace => { mailenabled => $reply->{mailenabled} } );
                }
                if( $reply->{logindisabled} ne 'do_not_change' )
                {
                        if( $reply->{logindisabled} eq 'yes' )
                        {
                                $this->disable_user($dn);
                        }
                        else
                        {
                                $this->enable_user($dn);
                        }
                }
                if( $reply->{internetdisabled} ne 'do_not_change' )
                {
                        $this->{LDAP}->modify( $dn, replace => { internetdisabled => $reply->{internetdisabled} } );
                }
                if( $reply->{oxenabled} ne 'do_not_change' )
                {
                        $this->{LDAP}->modify( $dn, replace => { oxenabled => $reply->{oxenabled} } );
                }
                if( $reply->{sambauserworkstations} ne 'do_not_change' )
                {
                        $this->{LDAP}->modify( $dn, delete => { sambauserworkstations => [] } );
                }
		if( $reply->{maynotchangepassword} ne 'do_not_change' )
		{
			if( $reply->{maynotchangepassword} eq 'yes' ){
                        	$this->{LDAP}->modify( $dn, delete => { sambaPwdCanChange => [] } );
                        	$this->{LDAP}->modify( $dn, delete => { shadowMin => [] } );
                        	$this->{LDAP}->modify( $dn, delete => { shadowMax => [] } );
                        	$this->{LDAP}->modify( $dn, add    => { sambaPwdCanChange => 2147483647 } );
                        	$this->{LDAP}->modify( $dn, add    => { shadowMin => 36500 } );
                        	$this->{LDAP}->modify( $dn, add    => { shadowMax => 0 } );
			}
			else
			{
                        	$this->{LDAP}->modify( $dn, delete  => { sambaPwdCanChange => [] } );
                        	$this->{LDAP}->modify( $dn, replace => { shadowMin => 0 } );
                        	$this->{LDAP}->modify( $dn, replace => { shadowMax => 99999 } );
			}
		}
        }
        $reply->{users} = join("\n",@users);
        $this->changeUserState($reply);
}

sub deleteUser
{
	my $this   = shift;
	my $reply  = shift;
	my @users  = split /\n/, $reply->{users}; 
	return noUser() if( ! scalar @users );

	my $freeze = encode_base64(freeze(\@users),"");
	main::AddSessionDatas($freeze,'deleteUser');
	my $list   = "";
        foreach my $dn ( @users )
	{
		$list .= $this->get_attribute($dn,'cn').',';
	}
	return [
		{ subtitle         => "Do you realy want to delete these users:" },
		{ label            => $list },
		{ action           => "cancel" },
		{ name => 'action', value => "deleteRealy", attributes => [ label => 'apply' ] }
	];
}

sub deleteRealy
{
	my $this   = shift;
	my $reply  = shift;
	my $freeze = decode_base64(main::GetSessionDatas('deleteUser'));
	my @users  = @{ thaw($freeze ) } if( defined $freeze );
        foreach my $dn ( @users )
	{
		$this->delete($dn);
	}
	$this->default;
}

sub setProfil
{
	my $this   = shift;
	my $reply  = shift;
	my @users  = split /\n/, $reply->{users}; 
	return noUser() if( ! scalar @users );

	my $freeze = encode_base64(freeze(\@users),"");
	main::AddSessionDatas($freeze,'setProfil');
	my $list   = "";
	my @templates = ();

        foreach my $dn ( @users )
	{
		$list .= $this->get_attribute($dn,'cn').',';
	}
	#Seraching for template users
	my $mesg = $this->{LDAP}->search (  # perform a search
                           base   => $this->{SYSCONFIG}->{USER_BASE},
                           scope  => 'one',
                           attrs => ['cn', 'uid'],
                           filter => '(role=templates)'
                          );
	foreach my $entry ($mesg->all_entries) {
	        my $cn  = $entry->get_value("cn");
	        my $uid = $entry->get_value("uid");
	        if( $cn ) {
	        	push @templates, [ $uid , $cn ];
	        } else {
	        	push @templates, [ $uid , $uid ];
	        }
	}
	push @templates, [ 'Default_User', 'Default User' ];

	return [
		{ subtitle         => "Set profil for these users:" },
		{ label            => $list },
		{ name => 'Win2K',    value => 0, attributes => [ type => 'boolean' ] },
		{ name => 'WinXP',    value => 0, attributes => [ type => 'boolean' ] },
		{ name => 'Win2K3',   value => 0, attributes => [ type => 'boolean' ] },
		{ name => 'Win7',     value => 0, attributes => [ type => 'boolean' ] },
		{ name => 'Linux',    value => 0, attributes => [ type => 'boolean' ] },
		{ name => 'template', value => \@templates, attributes => [ type => 'popup' ] },
		{ name => 'readOnly', value => 0, attributes => [ type => 'boolean' ] },
		{ action           => "cancel" },
		{ action           => "profil_ro" },
		{ action           => "profil_rw" },
		{ name => 'action', value => "deleteProfil",   attributes => [ label => 'delete' ] },
		{ name => 'action', value => "setProfilRealy", attributes => [ label => 'send_profile' ] }
	];
}

sub deleteProfil
{
        my $this   = shift;
        my $reply  = shift;
        my $freeze = decode_base64(main::GetSessionDatas('setProfil'));
        my @users  = @{ thaw($freeze ) } if( defined $freeze );
        foreach my $dn ( @users )
        {
                my $uid = get_name_of_dn($dn);
                system("/usr/sbin/oss_delete_profil.sh $uid Win2K")    if( $reply->{Win2K} );
                system("/usr/sbin/oss_delete_profil.sh $uid WinXP")    if( $reply->{WinXP} );
                system("/usr/sbin/oss_delete_profil.sh $uid Win2K3")   if( $reply->{Win2K3} );
                system("/usr/sbin/oss_delete_profil.sh $uid Vista.V2") if( $reply->{Win7} );
                system("/usr/sbin/oss_delete_profil.sh $uid Linux")    if( $reply->{Linux} );
        }
        $this->default;
}

sub setProfilRealy
{
	my $this   = shift;
	my $reply  = shift;
	my $freeze = decode_base64(main::GetSessionDatas('setProfil'));
	my @users  = @{ thaw($freeze ) } if( defined $freeze );
	my $ro     = $reply->{readOnly} ? 'ro' : '';
	my $templ  = $reply->{template};
        foreach my $dn ( @users )
	{
		my $uid = get_name_of_dn($dn);
		system("/usr/sbin/oss_copy_profil.sh $uid Win2K $templ $ro") if( $reply->{Win2K} );
		system("/usr/sbin/oss_copy_profil.sh $uid WinXP $templ $ro") if( $reply->{WinXP} );
		system("/usr/sbin/oss_copy_profil.sh $uid Win2K3 $templ $ro")if( $reply->{Win2K3} );
		system("/usr/sbin/oss_copy_profil.sh $uid Vista.V2 $templ $ro") if( $reply->{Win7} );
		system("/usr/sbin/oss_copy_profil.sh $uid Linux $templ $ro") if( $reply->{Linux} );
	}
	$this->default;
}

sub profil_rw
{
	my $this   = shift;
	my $reply  = shift;
	my $freeze = decode_base64(main::GetSessionDatas('setProfil'));
	my @users  = @{ thaw($freeze ) } if( defined $freeze );
        foreach my $dn ( @users )
	{
		my $uid = get_name_of_dn($dn);
		system('for i in `find /home/profile/'.$uid.' -name ntuser.man`; do mv $i ${i%/*}/ntuser.dat; done');
		system('for i in `find /home/profile/'.$uid.' -name NTUSER.MAN`; do mv $i ${i%/*}/NTUSER.DAT; done');
	}
	$this->default;
}

sub profil_ro
{
	my $this   = shift;
	my $reply  = shift;
	my $freeze = decode_base64(main::GetSessionDatas('setProfil'));
	my @users  = @{ thaw($freeze ) } if( defined $freeze );
        foreach my $dn ( @users )
	{
		my $uid = get_name_of_dn($dn);
		system('for i in `find /home/profile/'.$uid.' -name ntuser.dat`; do mv $i ${i%/*}/ntuser.man; done');
		system('for i in `find /home/profile/'.$uid.' -name NTUSER.DAT`; do mv $i ${i%/*}/NTUSER.MAN; done');
	}
	$this->default;
}

sub showUser
{
	my $this   = shift;
	my $reply  = shift;
	my @users  = split /\n/, $reply->{users}; 
	return noUser() if( ! scalar @users );

	my $dn     = $users[0];
	my @ret    = ();
	my $user   = $this->get_user($dn,\@userAttributeList);
	foreach my $attr ( @userAttributeList )
	{
		next if( $attr eq 'rasaccess' && ! $this->{RADIUS} );
		next if( $attr eq 'mailenabled' );
		next if( $attr =~/^susemail.*address|mail$/ && $user->{mailenabled}->[0] =~ /no/i );
		my $val = '';
		if( defined $user->{$attr} )
		{
			if( $attr eq 'group' )
			{
				foreach my $g (sort @{$user->{$attr}})
				{
					my $d = $this->get_attribute($g,'description') || $this->get_attribute($g,'cn');
					$val .= "$d<br>";
				}
			}
			else
			{
				$val = join "\n", @{$user->{$attr}};
			}
			push @ret, { name => $attr, value => $val, attributes => [ type=>'label' ] };
		}
	}
	push @ret, { action => 'cancel' };
	return \@ret;
}

sub exportUser
{
	my $this   = shift;
	my $reply  = shift;
	my @users  = split /\n/, $reply->{users}; 
	return noUser() if( ! scalar @users );
	my @Attributes = ('uid','sn','givenname','birthday','group');
	my @l      = ();
	my $List  = '';

	foreach my $attr ( @Attributes )
	{
		next if( $attr eq 'rasaccess' && ! $this->{RADIUS} );
		next if( $attr eq 'mailenabled' );
		if( $attr eq 'group' ){
			push @l, main::__('class');
		} else {
			push @l, main::__($attr);
		}
	}
	$List = join( ':',@l )."\r\n";
	foreach my $dn ( @users )
	{
		@l         = ();
		my $user   = $this->get_user($dn,\@Attributes);
		foreach my $attr ( @Attributes )
		{
			next if( $attr eq 'rasaccess' && ! $this->{RADIUS} );
			next if( $attr eq 'mailenabled' );
			my $val = '';
			if( defined $user->{$attr} )
			{
				if( $attr eq 'group' )
				{
					foreach my $g (sort @{$user->{$attr}})
					{
						next if( ! $this->is_class($g) );
						$val .= get_name_of_dn($g).' ';
					}
				}
				else
				{
					$val = join "\n", @{$user->{$attr}};
				}
			}
			push @l, $val;
		}
		$List .= join( ':',@l )."\r\n";
	}
        return [
                { name=> 'download' , value=>encode_base64($List), attributes => [ type => 'download', filename=>'userlist.txt', mimetype=>'text/plain' ] }
        ];

}
1;
