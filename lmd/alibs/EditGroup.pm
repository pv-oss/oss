# OSS LMD EditGroup module
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package EditGroup;

use strict;
use oss_group;
use oss_utils;
use oss_LDAPAttributes;
use Data::Dumper;

use vars qw(@ISA);
@ISA = qw(oss_group);

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    $connect->{withIMAP} = 1;
    my $self    = oss_group->new($connect);
    return bless $self, $this;
}

sub interface
{
        return [
                "getCapabilities",
                "default",
		"delete",
		"editAcls",
		"newMember",
		"setAcls",
		"addAcl",
		"setAcl",
		"setChanges",
                "edit"
        ];
}

sub getCapabilities
{
        return [
                { title        => 'Edit a Group' },
                { type         => 'command' },
                { allowedRole  => 'root' },
                { allowedRole  => 'sysadmins' },
                { allowedRole  => 'teachers' },
                { allowedRole  => 'teachers,sysadmins' },
                { category     => 'User' },
		{ order        => 50 },
                { variable     => [ "role",                     [ type => "list", size=>"3"] ] },
                { variable     => [ "class",                    [ type => "list", size=>"5"] ] },
                { variable     => [ "group",                    [ type => "list", size=>"5"] ] },
                { variable     => [ "ownerwriterdn",            [ type => "boolean" ] ] },
                { variable     => [ "cn",                       [ type => "label" ] ] },
                { variable     => [ "fquotaused",               [ type => "label" ] ] },
                { variable     => [ "quotaused",                [ type => "label" ] ] },
                { variable     => [ "dn",                       [ type => "hidden" ] ] },
                { variable     => [ "web",                      [ type => "boolean" ] ] },
                { variable     => [ "grouptype",                [ type => "popup" ] ] },
                { variable     => [ "member",                   [ type => "list", label => "member", help => 'Select Entry to delete', size=>"10", multiple=>"true"] ] },
                { variable     => [ "newmember",                [ type => "list", size=>"10", multiple=>"true"] ] },
                { variable     => [ "primarymember",            [ type => "text", help=>'For these users the actual group is the primary group. They can not be removed from this group.' ] ] },
                { variable     => [ "susedeliverytofolder",     [ type => "boolean" ] ] },
                { variable     => [ "susedeliverytomember",     [ type => "boolean" ] ] },
		{ variable     => [ "webdav_access",            [ type => "boolean" ] ] },
                { variable     => [ "fquota",                   [ type => "string", label => "fquota", backlabel => "MB" ] ] },
                { variable     => [ "quota",                    [ type => "string", label => "quota", backlabel => "MB" ] ] },
		{ variable     => [ "l", [ type => "boolean"]]},
		{ variable     => [ "r", [ type => "boolean"]]},
		{ variable     => [ "s", [ type => "boolean"]]},
		{ variable     => [ "w", [ type => "boolean"]]},
		{ variable     => [ "i", [ type => "boolean"]]},
		{ variable     => [ "p", [ type => "boolean"]]},
		{ variable     => [ "k", [ type => "boolean"]]},
		{ variable     => [ "x", [ type => "boolean"]]},
		{ variable     => [ "t", [ type => "boolean"]]},
		{ variable     => [ "e", [ type => "boolean"]]},
		{ variable     => [ "a", [ type => "boolean"]]},
                { variable     => [ "owner",                    [ type => "label" ] ] },
                { variable     => [ "newowner",                 [ type => "list", size=>"10", multiple=>"true" ] ] },
                { variable     => [ "susemailforwardaddress",   [ type => "list", label => "susemailforwardaddress", help => 'Select Entry to delete', size=>"5", multiple=>"true" ] ] },
                { variable     => [ "susemailacceptaddress",    [ type => "list", label => "susemailacceptaddress", help => 'Select Entry to delete', size=>"5", multiple=>"true"] ] }
        ];
}

sub default
{
        my $this   = shift;
        my $reply  = shift;
	my @ret    = ( { subtitle    => 'Select Group' } );
	if( $this->{LDAP_BASE} ne main::GetSessionValue('sdn') )
	{
	       push @ret, { label => main::__( 'Selected School: '). $this->get_attribute(main::GetSessionValue('sdn'),'o') };
	}

        if( main::GetSessionValue('role') eq 'teachers' )
	{
        	my ( $roles, $classes, $workgroups ) = $this->get_school_groups_to_search(main::GetSessionValue('dn'));
		push @ret, { group       => $workgroups };
		push @ret, { rightaction => "edit" };
		push @ret, { rightaction => "delete" };
	}
	elsif( main::GetSessionValue('role') =~ /sysadmins|root$/ )
	{
        	my ( $roles, $classes, $workgroups ) = $this->get_school_groups_to_search();
		push @ret, { role        => $roles };
		push @ret, { class       => $classes };
		push @ret, { group       => $workgroups };
		push @ret, { rightaction => "edit" };
		push @ret, { rightaction => "editAcls" };
		push @ret, { rightaction => "delete" };
	}
	return \@ret;
}

sub delete
{
        my $this   = shift;
        my $reply  = shift;
	my $dn	   = $reply->{class} || $reply->{group};
	$dn =  $reply->{role} if ( ! $dn );

	if( ! $dn )
	{
		return { TYPE    => 'ERROR',
			 MESSAGE => 'Please select a Workgroup or a Class to Edit'
		};	 
	}

	if( ! $this->SUPER::delete($dn) )
        {
                return {
                        TYPE => 'ERROR',
                        MESSAGE => $this->{ERROR}->{text}
                }
        }
	$this->default();
}

sub edit
{
        my $this   = shift;
        my $reply  = shift;
	my $dn	   = undef;
	if( defined $reply->{dn} )
	{
		$dn = $reply->{dn};
	}
	else
	{
		$dn = $reply->{class} || $reply->{group};
		$dn =  $reply->{role} if ( ! $dn );
	}
	my $filter = $reply->{filter} || '*';

	if( ! $dn )
	{
		return { TYPE    => 'ERROR',
			 MESSAGE => 'Please select a Workgroup or a Class to Edit'
		};	 
	}
	my @ret   = ();
	my $group = $this->get_group($dn);
        foreach my $attr ( @defaultGroupAttributes )
        {
                my $val = undef;
                if( defined $group->{$attr} )
                {
                        if( $attr =~ /^susemail.*address$/ )
                        {
                                $val =  $group->{$attr};
                        }
                        elsif( $attr =~ /^member$/ )
                        {
				my @members        = ();
				my @primarymembers = ();
				foreach my $member ( sort @{$group->{$attr}} )
				{
					next if ( $member =~ /cn=Administrator|uid=Administrator/ );
					my $user = $this->get_user($member,[ 'uid', 'cn', 'description' , 'gidnumber' ] );
					if( $group->{grouptype}->[0] eq 'primary' && $user->{gidnumber}->[0] eq $group->{gidnumber}->[0] )
					{ 
						push @primarymembers, $user->{uid}->[0].' '.$user->{cn}->[0].' ('.$user->{description}->[0].')';
					}
					else
					{
						push @members,        [ $member, $user->{uid}->[0].' '.$user->{cn}->[0].' ('.$user->{description}->[0].')' ];
					}
				}
				if( scalar  @primarymembers )
				{
					push @ret, { primarymember => join("\n",@primarymembers) };
				}
				$val = \@members;
                        }
                        elsif( $attr =~ /^susedeliverytofolder|susedeliverytomember$/ )
                        { 
				if( $group->{$attr}->[0] eq 'yes' ) 
				{
					$val = 1;
				}
				else
				{
					$val = 0;
				}
                        }
                        else
                        {
                                $val = join '', @{$group->{$attr}};
                        }
                }
		else
		{
			next if ( $attr =~ /^fquota/ );
		}
		if( main::GetSessionValue('role') eq 'teachers' )
		{
			if( $attr eq 'fquota' || $attr eq 'quota' )
			{
				next;
			}
		}
                push @ret, { $attr => $val };
                if( $attr =~ /^susemailacceptaddress$/ )
                {
                        push @ret, { newsusemailacceptaddress => '' };
                }
                if( $attr =~ /^susemailforwardaddress$/ )
                {
                        push @ret, { newsusemailforwardaddress => '' };
                }
        }
	my $webdav_access_value = $this->get_vendor_object($dn,'EXTIS','WebDavAccess') ;
	push @ret, { webdav_access => "$webdav_access_value->[0]" };
        push @ret, { dn           => $dn };
        push @ret, { action       => "cancel" };
        push @ret, { action       => "newMember" };
        push @ret, { name => 'action', value => "setChanges", attributes => [ label => 'apply' ]  };
        return \@ret;

}

sub newMember
{
        my $this   = shift;
        my $reply  = shift;
	my $dn	   = undef;
	if( defined $reply->{dn} )
	{
		$dn = $reply->{dn};
	}
	else
	{
		$dn = $reply->{class} || $reply->{group};
		$dn = $reply->{role} if ( ! $dn );
	}
	my $filter = $reply->{filter} || '*';

	if( ! $dn )
	{
		return { TYPE    => 'ERROR',
			 MESSAGE => 'Please select a Workgroup or a Class to Edit'
		};	 
	}
	my $group = $this->get_group($dn);
	my @ret   = ();
        my ( $roles, $classes, $workgroups ) = $this->get_school_groups_to_search();
	push @ret, { notranslate_subtitle       => $group->{description}->[0]." (".$group->{cn}->[0].")" };
	push @ret, { filter      => $filter };
	push @ret, { role        => $roles };
	push @ret, { class       => $classes };
	push @ret, { group       => $workgroups };
	my $f = "(|(uid=$filter)(name=$filter))";
	$f .= '(memberof='.$reply->{role}.')'  if( $reply->{role} );
	$f .= '(memberof='.$reply->{class}.')' if( $reply->{class} );
	$f .= '(memberof='.$reply->{group}.')' if( $reply->{group} );
	# now we create the lis of none member
	my @newmembers = ();
	my $result = $this->{LDAP}->search( base   => $this->{SCHOOL_BASE},
					    filter => "(&(objectClass=schoolAccount)(!(role=workstations))(!(role=templates))(!(memberof=$dn))$f)",
					    attrs  => [ 'uid', 'cn', 'description' ]
					    );
	my $entries = $result->as_struct;
	foreach my $dn ( sort keys %{$entries} )
	{
		push @newmembers, [ $dn, $entries->{$dn}->{'uid'}->[0].' '.$entries->{$dn}->{'cn'}->[0].' ('.$entries->{$dn}->{'description'}->[0].')' ];
	}
        push @ret, { newmember => \@newmembers };
        push @ret, { dn           => $dn };
        push @ret, { action       => "cancel" };
        push @ret, { name => 'action', value => "newMember",  attributes => [ label => 'search' ]  };
        push @ret, { name => 'action', value => "setChanges", attributes => [ label => 'apply' ]  };
        return \@ret;
}

sub setChanges
{
        my $this   = shift;
        my $reply  = shift;
	make_array_attributes($reply);
        if( ! $this->modify($reply) )
        {
                return {
                     TYPE    => 'ERROR',
                     CODE    => $this->{ERROR}->{code},
                     MESSAGE_NOTRANSLATE => $this->{ERROR}->{text}
                }
        }

        $this->edit( { group => $reply->{dn}} );
}

sub editAcls
{
        my $this   = shift;
        my $reply  = shift;
	my @acl    = ('acl');
	my $dn	   = $reply->{class} || $reply->{group};
	$dn =  $reply->{role} if ( ! $dn );
	my $acls   = $this->get_mbox_acl($dn);

	push @acl, { head => [
		{ name => 'owner', attributes => [ label => '' ] },
		{ name => 'l', attributes => [ label => 'Lookup',      help => 'Mailbox is visible to LIST/LSUB commands, SUBSCRIBE mailbox'	]},
                { name => 'r', attributes => [ label => 'Read',        help => 'SELECT the mailbox, perform STATUS'				]},
                { name => 's', attributes => [ label => 'Seen',        help => 'Keep seen/unseen information across sessions'		]},
                { name => 'w', attributes => [ label => 'Write',       help => 'Set or clear flags other than \SEEN and \DELETED'		]},
                { name => 'i', attributes => [ label => 'Insert',      help => 'Perform APPEND, COPY into mailbox' 				]},
                { name => 'p', attributes => [ label => 'Post',        help => 'Send mail to submission address for mailbox' 		]},
                { name => 'k', attributes => [ label => 'Create MBox', help => 'Create new sub-mailboxes in any implementation-defined hierarchy']},
                { name => 'x', attributes => [ label => 'Delete MBox', help => 'Delete the mailbox itself'					]},
                { name => 't', attributes => [ label => 'Delete Mail', help => 'Set or clear \DELETED flag via STORE' 			]},
                { name => 'e', attributes => [ label => 'Expunge',     help => 'Perform EXPUNGE and expunge as a part of CLOSE'		]},
                { name => 'a', attributes => [ label => 'Admin',       help => 'Administer, perform SETACL/DELETEACL/GETACL/LISTRIGHTS' 	]}
		
			] } ;
	foreach ( sort keys %{$acls} )
	{
		my $t = $acls->{$_};
		push @acl, {line => [ $_ , {owner=>$_}, {notranslate_l=>($t=~/l/)}, {notranslate_r=>($t=~/r/)},
							{notranslate_s=>($t=~/s/)}, {notranslate_w=>($t=~/w/)},
							{notranslate_i=>($t=~/i/)}, {notranslate_p=>($t=~/p/)},
							{notranslate_k=>($t=~/k/)}, {notranslate_x=>($t=~/x/)},
							{notranslate_t=>($t=~/t/)}, {notranslate_e=>($t=~/e/)},
							{notranslate_a=>($t=~/a/)}] };
	}
	return
	[
                { notranslate_label    => get_name_of_dn($dn) },
		{ table  => \@acl },
		{ dn     => $dn   },
		{ action => 'cancel' },
		{ action => 'addAcl' },
		{ name => 'action', value=> 'setAcls', attributes => [ label => 'apply' ] }
	];
}

sub setAcls
{
        my $this     = shift;
        my $reply    = shift;
        my $dn       = $reply->{dn};
	foreach(keys %{$reply->{acl}})
	{
		my $acl = '';
		$acl .= 'l' if( $reply->{acl}->{$_}->{l} );
		$acl .= 'r' if( $reply->{acl}->{$_}->{r} );
		$acl .= 's' if( $reply->{acl}->{$_}->{s} );
		$acl .= 'w' if( $reply->{acl}->{$_}->{w} );
		$acl .= 'i' if( $reply->{acl}->{$_}->{i} );
		$acl .= 'p' if( $reply->{acl}->{$_}->{p} );
		$acl .= 'k' if( $reply->{acl}->{$_}->{k} );
		$acl .= 'x' if( $reply->{acl}->{$_}->{x} );
		$acl .= 't' if( $reply->{acl}->{$_}->{t} );
		$acl .= 'e' if( $reply->{acl}->{$_}->{e} );
		$acl .= 'a' if( $reply->{acl}->{$_}->{a} );
		$this->set_mbox_acl($dn,$_,$acl);
	}
	$this->editAcls( { class => $dn } );
}

sub addAcl
{
        my $this     = shift;
        my $reply    = shift;
        my $filter   = $reply->{filter} || '*';
        my $dn       = $reply->{dn};
        my @newowner = ();
        my $result = $this->{LDAP}->search( base   => $this->{SCHOOL_BASE},
                                           filter => "(&(objectClass=schoolGroup)(name=$filter))",
                                           attrs  => [ 'cn', 'description' ]
                                           );
        my $entries = $result->as_struct;
        foreach my $dn ( sort keys %{$entries} )
        {
               push @newowner, [ $dn, $entries->{$dn}->{'cn'}->[0].' ('.$entries->{$dn}->{'description'}->[0].')' ];
        }
        $result = $this->{LDAP}->search( base   => $this->{SCHOOL_BASE},
                                           filter => "(&(objectClass=schoolAccount)(!(role=workstations))(!(role=templates))(name=$filter))",
                                           attrs  => [ 'uid', 'cn', 'description' ]
                                           );
        $entries = $result->as_struct;
        foreach my $dn ( sort keys %{$entries} )
        {
               push @newowner, [ $dn, $entries->{$dn}->{'uid'}->[0].' '.$entries->{$dn}->{'cn'}->[0].' ('.$entries->{$dn}->{'description'}->[0].')' ];
        }
        return [
		{ subtitle             => 'addAcl' },
                { notranslate_label    => get_name_of_dn($dn) },
                { filter   => $filter },
                { newowner => \@newowner },
		{ name => 'l', value => $reply->{l}, attributes => [ type => 'boolean', label => 'Lookup',      help => 'Mailbox is visible to LIST/LSUB commands, SUBSCRIBE mailbox'	]},
                { name => 'r', value => $reply->{r}, attributes => [ type => 'boolean', label => 'Read',        help => 'SELECT the mailbox, perform STATUS'				]},
                { name => 's', value => $reply->{s}, attributes => [ type => 'boolean', label => 'Seen',        help => 'Keep seen/unseen information across sessions'		]},
                { name => 'w', value => $reply->{w}, attributes => [ type => 'boolean', label => 'Write',       help => 'Set or clear flags other than \SEEN and \DELETED'		]},
                { name => 'i', value => $reply->{i}, attributes => [ type => 'boolean', label => 'Insert',      help => 'Perform APPEND, COPY into mailbox' 				]},
                { name => 'p', value => $reply->{p}, attributes => [ type => 'boolean', label => 'Post',        help => 'Send mail to submission address for mailbox' 		]},
                { name => 'k', value => $reply->{k}, attributes => [ type => 'boolean', label => 'Create MBox', help => 'Create new sub-mailboxes in any implementation-defined hierarchy']},
                { name => 'x', value => $reply->{x}, attributes => [ type => 'boolean', label => 'Delete MBox', help => 'Delete the mailbox itself'					]},
                { name => 't', value => $reply->{t}, attributes => [ type => 'boolean', label => 'Delete Mail', help => 'Set or clear \DELETED flag via STORE' 			]},
                { name => 'e', value => $reply->{e}, attributes => [ type => 'boolean', label => 'Expunge',     help => 'Perform EXPUNGE and expunge as a part of CLOSE'		]},
                { name => 'a', value => $reply->{a}, attributes => [ type => 'boolean', label => 'Admin',       help => 'Administer, perform SETACL/DELETEACL/GETACL/LISTRIGHTS' 	]},
                { dn       => $dn },
                { action   => "cancel" },
                { name     => 'action', value   => "addAcl" , attributes => [ label => 'search' ] },
                { name     => 'action', value   => "setAcl" , attributes => [ label => 'set' ] }
        ]

}

sub setAcl
{
        my $this     = shift;
        my $reply    = shift;
        my $filter   = $reply->{filter} || '*';
        my $dn       = $reply->{dn};
	my $acl      = '';
	$acl .= 'l' if( $reply->{l} );
	$acl .= 'r' if( $reply->{r} );
	$acl .= 's' if( $reply->{s} );
	$acl .= 'w' if( $reply->{w} );
	$acl .= 'i' if( $reply->{i} );
	$acl .= 'p' if( $reply->{p} );
	$acl .= 'k' if( $reply->{k} );
	$acl .= 'x' if( $reply->{x} );
	$acl .= 't' if( $reply->{t} );
	$acl .= 'e' if( $reply->{e} );
	$acl .= 'a' if( $reply->{a} );
	foreach( split /\n/, $reply->{newowner} )
	{
		$this->set_mbox_acl($dn,$_,$acl);
	}
	$this->editAcls( { class => $dn } );
}
1;
