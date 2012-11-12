=head1 NAME
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

 oss_user

=head1 PREFACE

 This package is the public perl API to configure the OpenSchoolServer.

=head1 SYNOPSIS

 #!/usr/bin/perl 
 
 BEGIN{ push @INC,"/usr/share/oss/lib/"; }
 
 use oss_user;

 my $oss_user = oss_user->new();
 
 $oss_user->delete('uid=micmou,ou=people,dc=schule,dc=de');

=head1 DESCRIPTION

B<oss_user>  is a collection of functions that implement a OpenSchoolServer 
configuration API for Perl programs to add, modify, search and delete user.

=over 2

=cut

#TODO 
#
# 1. we have to implement a syntax check for all LDAP-Attributes

BEGIN{ 
  push @INC,"/usr/share/oss/lib/"; 
}

package oss_user;

use strict;
use oss_base;
use oss_utils;
use oss_LDAPAttributes;
use ossBaseTranslations;
use Net::LDAP;
use Net::LDAP::Entry;
use Net::IMAP;
use Time::Local;
# The standard output format is XML
# Debug only
use Data::Dumper;

use vars qw(@ISA);
@ISA = qw(oss_base);
#-----------------------------------------------------------------------

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    my $self    = oss_base->new($connect);
    return bless $self, $this;
}
#-----------------------------------------------------------------------

=item B<add(UserHash)>

Create a user and returns the dn of the new user. The only parameter is a pointer to 
a hash containig the users attributes. 

IMPORTANT: The hash keys must be in lower case.

EXAMPLE:

   $oss_user->add(      role => 'teachers', 
		    birthday => '1967-04-17',
		          sn => 'Varkoly',
	 	   givenname => 'Péter',
		userpassword => 'VeRisEcrE1'
		       class => ['cn=10D,ou=group,dc=oss-extis,dc=de','cn=5D,ou=group,dc=oss-extis,dc=de']
		);

All LDAP-attributes of the objectclasses 'top' ,'shadowAccount' ,'posixAccount' ,'person' ,'inetOrgPerson' ,'SchoolAccount' ,'OXUserObject' ,'phpgwAccount' ,'suseMailRecipient' ,'sambaSamAccount' are allowed.

Spetial attributes (hash keys):

	templateuserdn	: A DN of a user which will be used as a template for the new user
	mbox		: Array of mail boxes which will be created for the new user
	quota		: Mail quota of the user
	fquota		: File system quota of the user
	admin		: The user has system administrator rights 0 or 1 (boolean)
	class		: The class(es) the new user belongs to. If class = all means
			  the new user belongs all actuall existent classes.
	group		: The group(s) the new user belongs to

Folloing attributes must be given in an array:

	class, group, susemailacceptaddress

=cut

sub add($)
{
    my $this     = shift;
    my $USER     = shift;
    my $ERR      = '';
    my $pwmech   = 'md5';
    my $TEMPLATE = undef;
    my $uid      = undef;

    print "===========START=======addUSER\n".Dumper($USER) if ($this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes');
    # Check if the ldap attributes are OK
    $ERR = check_user_ldap_attributes($USER);
    if($ERR ne '' )
    {
        $this->{ERROR}->{text}  = $ERR;
        $this->{ERROR}->{code}  = 'BAD-USER-ATTRIBUTES';
        return undef;
    }

    #There is a school defined
    if( defined $USER->{oid} )
    {
        $this->init_sysconfig($this->get_school_base($USER->{oid}));
    }
#   I think it is not necessary becouse it will be done by oss_user->new
#    if( defined $USER->{sDN} )
#    {
#        $this->init_sysconfig($USER->{sDN});
#    }
#    print Dumper($this->{SYSCONFIG}) if ($this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes');

    # Now we create the uid
    if( ! $USER->{uid} )
    {
	$this->create_uid($USER);
    }
    elsif ( defined $this->{SYSCONFIG}->{SCHOOL_LOGIN_PREFIX} )
    {
	$uid = lc($USER->{uid});
        $USER->{uid} = $this->{SYSCONFIG}->{SCHOOL_LOGIN_PREFIX}.$USER->{uid};
    }
    # We take care that uids are every time lower case
    $USER->{uid} = lc($USER->{uid});

    # Create the DN of the user entry
    $USER->{prefix} = '' if ( !defined $USER->{prefix} );
    if( $USER->{role} eq 'machine' )
    {
        $USER->{dn} =  'uid='.$USER->{uid}.','.$this->{SYSCONFIG}->{COMPUTERS_BASE};
    }
    elsif( $USER->{role} eq 'workstations' )
    {
        $USER->{dn} =  'uid='.$USER->{uid}.','.$this->{SYSCONFIG}->{USER_BASE};
    }
    else
    {
        $USER->{dn} =  'uid='.$USER->{prefix}.$USER->{uid}.','.$this->{SYSCONFIG}->{USER_BASE};
    }
    # Now we create the uidnumber
    if( ! $USER->{uidnumber} )
    {
        $USER->{uidnumber} = $this->get_next_unique('user');
    }

    # Check if we have a complex role 
    if( $USER->{role} =~ /(.*),templates/ )
    {
        $USER->{role}                  = "templates";
        my $pgdn                       = $this->get_primary_group($1);
        $USER->{gidnumber}             = $this->get_attribute($pgdn,'gidnumber');
        $USER->{sambaprimarygroupsid}  = $this->get_attribute($pgdn,'sambasid');
        my $tdn = $this->get_entries_dn('(&(objectClass=schoolGroup)(role=templates))');
        if( $tdn->[0] )
        {
             push @{$USER->{group}}, get_name_of_dn($tdn->[0]);
        }

    }
    elsif( $USER->{role} ne 'machine' )
    {
            my $pgdn                       = $this->get_primary_group($USER->{role});
	    if( ! defined $pgdn )
	    {
        	$this->{ERROR}->{text}  = "Can not find the primary group for ".$USER->{role};
        	$this->{ERROR}->{code}  = 'NO-PRIMARY-GROUP';
        	return undef;
	    }
	    $USER->{gidnumber}             = $this->get_attribute($pgdn,'gidnumber');
	    $USER->{sambaprimarygroupsid}  = $this->get_attribute($pgdn,'sambasid');
    }
    # Inherit user attributes from the template user.
    if( !$USER->{templateuserdn} )
    {
        $USER->{templateuserdn} = $this->get_template_user($USER->{role});
	print "1 Template user dn ".$USER->{templateuserdn}." \n" if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' );
    }
    if( $USER->{templateuserdn} )
    {
        $TEMPLATE = $this->get_entry($USER->{templateuserdn});
    }
    elsif( $USER->{role} eq 'machine' )
    {
       $TEMPLATE = \%defaultMachineAccount;
    }
    else
    {
       $TEMPLATE = \%defaultUser;
    }
    print "Template\n".Dumper($TEMPLATE) if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' ) ;
    foreach my $i ( @userAttributesToInherit )
    {
        if( $TEMPLATE->{$i} && ! $USER->{$i})
	{
	    print "inherit $i\n" if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' );
	    if( scalar @{$TEMPLATE->{$i}} > 1 )
	    {
	        $USER->{$i} = $TEMPLATE->{$i};
	    }
	    else
	    {
	        $USER->{$i} = $TEMPLATE->{$i}->[0];
	    }
	}
    }
    print "After inherit\n".Dumper($USER) if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' ); 
    # Now we check/create the mail adresses
    if( ! $USER->{mailenabled}  && $USER->{role} ne 'machine' )
    {
        $USER->{mailenabled} = 'ok';
        if( $USER->{role} =~ /^templates|workstations$/ )
	{
            $USER->{mailenabled} = 'no';
	}
	elsif( $USER->{role} eq 'students' )
	{
	    if( $this->{SYSCONFIG}->{SCHOOL_NO_EXTERN_MAIL} eq 'yes' )
	    {
	       $USER->{mailenabled} = 'local_only';
	    }
	}
    }
    if( $USER->{mailenabled} ne 'no' && $USER->{role} ne 'machine' )
    {
	push @{$USER->{susemailacceptaddress}}, $USER->{uid}.'@'.$this->{SYSCONFIG}->{SCHOOL_DOMAIN};
	if( $USER->{alias} )
	{
	    my $alias = string_to_ascii($USER->{givenname}.'.'.$USER->{sn},1).'@'.$this->{SYSCONFIG}->{SCHOOL_DOMAIN}; 
	    if( $USER->{c} eq 'HU' )
	    {
	       $alias = string_to_ascii($USER->{sn}.'.'.$USER->{givenname},1).'@'.$this->{SYSCONFIG}->{SCHOOL_DOMAIN}; 
	    }
	    if( $this->is_unique($alias,'mail') )
	    {
		push @{$USER->{susemailacceptaddress}}, $alias;
		$USER->{mail} = $alias;
	    }
	}
	else
	{
		$USER->{mail} = $USER->{uid}.'@'.$this->{SYSCONFIG}->{SCHOOL_DOMAIN};
        }
	if ( defined $this->{SYSCONFIG}->{SCHOOL_LOGIN_PREFIX} and $this->{SYSCONFIG}->{SCHOOL_LOGIN_PREFIX} ne '' )
	{
		$USER->{mail} = $uid.'@'.$this->{SYSCONFIG}->{SCHOOL_DOMAIN};
		push @{$USER->{susemailacceptaddress}}, $USER->{mail};
	}

    }

    #Set the home directory
    $USER->{homedirectory} = $this->{SYSCONFIG}->{SCHOOL_HOME_BASE}.'/'.$USER->{role}.'/'.$USER->{uid};
    $USER->{profiledir}    = $this->{SYSCONFIG}->{SCHOOL_HOME_BASE}.'/profile/'.$USER->{uid};


    #Now we set the samba attributes
    if( ! $this->set_samba_attributes($USER) )
    {
	print STDERR Dumper($USER);
        return undef;
    }

    #Now we create password an password attributes
    $USER->{cleartextpassword} = $USER->{userpassword};
    if( $USER->{role} ne 'machine' )
    {
	    $USER->{userpassword}      = hash_password($pwmech,$USER->{userpassword}) ;
    }    
    if( $USER->{mustchange} )
    {
        $USER->{sambapwdmustchange} = 0 ;
	$USER->{sambapwdlastset}    = 0;
        $USER->{shadowlastchange}   = 0 ;
    }
    else
    {
        $USER->{sambapwdmustchange} = 2147483647;
        $USER->{sambapwdlastset}    = timelocal(localtime());
        $USER->{shadowlastchange}   = int(timelocal(localtime()) / 3600 / 24);
    }

    # Now we create the cn
    if( ! $USER->{cn} )
    {
	$this->create_cn($USER);
    }
    # Create Description if not defined
    if( ! $USER->{description} )
    {
    	if( $USER->{preferredlanguage} && $Translations->{$USER->{preferredlanguage}}->{$USER->{role}} )
	{
	    $USER->{description} = $Translations->{$USER->{preferredlanguage}}->{$USER->{role}};
	}
	else
	{
	    $USER->{description} = $USER->{role};
	}
    }
    #Create an empty user
    my $USEREntry= Net::LDAP::Entry->new();
    $USEREntry->dn( $USER->{dn} );

    $USER->{uid} = $USER->{prefix}.$USER->{uid};
    # Now we set the user attributes
    foreach my $i ( keys %{$USER} )
    {
	next if ( $i eq 'role' && $USER->{role} eq 'machine' );
        if( is_user_ldap_attribute($i) )
	{
	    $USEREntry->add( $i => $USER->{$i} );
	}
    }

    #Now we are ready we create the entry
    print Dumper($USER) if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' ); 
    print Dumper($USEREntry) if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' ); 
    my $mesg = $USEREntry->update( $this->{LDAP} );
    if( $mesg->code() )
    {
        $this->ldap_error($mesg);
        return 0;
    }
    print "USER Successfully Created\n"  if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' );

    if( $USER->{role} ne 'machine' )
    { #Now we create the home & profile directories & put the user in the groups
        my $skel = $TEMPLATE->{homedirectory}->[0];
        if( ! -d $skel )
        {
           $skel = '/etc/skel';
        }
        my $command = 'mkdir -p '.$USER->{homedirectory}.'/public_html '.$USER->{profiledir}.";\n";

      	# Copy profile 
	my $tprofile = $this->{SYSCONFIG}->{SCHOOL_HOME_BASE}.'/profile/t'.$USER->{role};
	if( -d $tprofile )
	{
		$command .= 'rsync -a '.$tprofile.'/ '.$USER->{profiledir}."/;\n";
	}
        $command .= 'chown -R '.$USER->{uidnumber}.':'.$USER->{gidnumber}.' '.$USER->{profiledir}.";\n".
		    'chmod -R 700 '.$USER->{profiledir}.";\n".
            	    'setfacl -dm u::rwx '.$USER->{profiledir}.";\n".
        	    'rsync -a '.$skel.'/ '.$USER->{homedirectory}."/\n";
        if( $USER->{role} eq 'workstations' || ($USER->{role} eq 'students' &&  $this->{SYSCONFIG}->{SCHOOL_TEACHER_OBSERV_HOME} eq 'yes' ))
        {
                $command .= 'chown -R '.$USER->{uidnumber}.':teachers '.$USER->{homedirectory}.";\n".
			    'find '.$USER->{homedirectory}.' -type d -exec chmod 2771  {} \;'."\n".
			    'find '.$USER->{homedirectory}.' -type d -exec setfacl -dm g:teachers:rwx {} \;'."\n";
        }
        else
        {
                $command .= 'chown -R '.$USER->{uidnumber}.':'.$USER->{gidnumber}.' '.$USER->{homedirectory}.";\n".
                            'chmod 711 '.$USER->{homedirectory}.";\n";
        }
        $command .= 'setfacl    -m u:wwwrun:rx '.$USER->{homedirectory}."/public_html;\n".
                    'setfacl -d -m u:wwwrun:rx '.$USER->{homedirectory}."/public_html;\n";
        
        
        #Create some usefull symlinks
        $command .= 'test -e '.$USER->{homedirectory}.'/+software || ln -s '.$this->{SYSCONFIG}->{SCHOOL_HOME_BASE}.'/software '.$USER->{homedirectory}."/+software\n";
        if( $USER->{role} ne 'workstations' )
        {
            $command .= 'test -e '.$USER->{homedirectory}.'/+all || ln -s '.$this->{SYSCONFIG}->{SCHOOL_HOME_BASE}.'/all '.$USER->{homedirectory}."/+all\n";
            $command .= 'test -e '.$USER->{homedirectory}.'/+groups || ln -s '.$this->{SYSCONFIG}->{SCHOOL_HOME_BASE}.'/groups '.$USER->{homedirectory}."/+groups\n";
        }
        if( $USER->{role} eq 'teachers' )
        {
            $command .= 'test -e '.$USER->{homedirectory}.'/+allteachers || ln -s '.$this->{SYSCONFIG}->{SCHOOL_HOME_BASE}.'/groups/TEACHERS '.$USER->{homedirectory}."/+allteachers\n";
            if( $this->{SYSCONFIG}->{SCHOOL_TEACHER_OBSERV_HOME} eq 'yes' )
            {
                $command .= 'test -e '.$USER->{homedirectory}.'/+classes || ln -s '.$this->{SYSCONFIG}->{SCHOOL_HOME_BASE}.'/classes '.$USER->{homedirectory}."/+classes\n";
            }
        }
        #Setting filesystem quota
        if( !defined $USER->{fquota} || $USER->{fquota} eq '' )
        {
           if( $USER->{role} =~ /teachers|administration|sysadmins/)
           {
              $USER->{fquota} = $this->{SYSCONFIG}->{SCHOOL_FILE_TEACHER_QUOTA};
           }
           else
           {
              $USER->{fquota} = $this->{SYSCONFIG}->{SCHOOL_FILE_QUOTA};
           }
        }
        if( $USER->{fquota} )
        {
	    $this->set_fquota($USER->{dn},$USER->{fquota});
        }
        print "Create User directories".$command  if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' );
        system( $command );

	#Now we add user to his groups
        print "Add usert to primary group\n"  if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' );
	$this->add_user_to_group($USER->{dn},$this->get_primary_group($USER->{role}));
	# Every user is DOMAINUSER
	$this->add_user_to_group($USER->{dn},$this->get_group_dn('DOMAINUSERS'));
	if( defined $USER->{group} )
	{
            print "Add user to groups\n"  if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' );
	    foreach my $group ( @{$USER->{group}} )
	    {
	        $this->add_user_to_group($USER->{dn},$group);
	    }
	}
	
	#Now we add user to his classes
	if( defined $USER->{class} )
	{
            print "Add user to classes\n"  if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' );
	    if( $USER->{class}->[0] =~ /^all$/i )
	    {
	        foreach my $classDN ( @{$this->get_school_groups('class')} )
	        {
	            $this->add_user_to_group($USER->{dn},$classDN);
	        }
	    }
	    else
	    {
	        foreach my $class ( @{$USER->{class}} )
	        {
	            $this->add_user_to_group($USER->{dn},$class);
	        }
	    }
	}

	#user webdav share
	if($USER->{webdav_access}){
		$this->make_delete_user_webdavshare( "$USER->{dn}", "$USER->{webdav_access}" );
	}

	#set students "MAY_NOT_CHANGE_PASSWORD"  "MayNotChangePassword"
	if( $USER->{role} eq 'students' ){
		my $not_change_password = $this->get_school_config('SCHOOL_MAY_NOT_CHANGE_PASSWORD');
		$this->create_vendor_object( "$USER->{dn}", 'EXTIS', 'MayNotChangePassword', "$not_change_password" );
	}
	
	#If this is a user with admin rights
	if( $USER->{admin} && $USER->{role} ne 'sysadmins' )
	{
            print "Add user to sysadmins\n"  if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' );
	    $this->add_user_to_group($USER->{dn},$this->get_primary_group('sysadmins'));
	    $this->{LDAP}->modify( $USER->{dn}, replace => { role => $USER->{role}.',sysadmins' } );
	}
	#Setting mailquota
	if( !defined $USER->{quota} || $USER->{quota} eq '' )
	{
	   if( $USER->{role} =~ /teachers|administration|sysadmins/)
	   {
	      $USER->{quota} = $this->{SYSCONFIG}->{SCHOOL_MAIL_TEACHER_QUOTA};
	   }
	   else
	   {
	      $USER->{quota} = $this->{SYSCONFIG}->{SCHOOL_MAIL_QUOTA};
	   }
	}
	#Now we create the mailboxes of the user
	if( $USER->{role} !~ /templates|workstations|machine/ )
	{
            print "Create Mailboxes\n"  if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' );
	    $this->create_mbox($USER->{dn}, $USER );
            print "Create private addressbook\n"  if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' );
	    $this->{LDAP}->add( 'ou=addr,'.$USER->{dn}, attr => [ objectClass => [ 'top' , 'organizationalUnit' ] , ou => 'addr' ] );
	}

    } #End create home and profile directory
    if( $USER->{role} eq 'machine' )
    { # no plugin for machine accounts
        return $USER->{dn};
    }
    #Now we start the plugins
    print "Create plugin attributes\n"  if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' );
    my $attrs = '';
    foreach my $i ( keys %{$USER} )
    {
        if( $USER->{$i} =~ /^ARRAY/ )
	{
	    foreach my $j ( @{$USER->{$i}} )
	    {
	        $attrs .= $i.' '.$j."\n";
	    }
	}
	else
	{
	    $attrs .= $i.' '.$USER->{$i}."\n";
	}
    }
    print $attrs if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' );
    my $TMPFILE = write_tmp_file($attrs);
    system("/usr/share/oss/plugins/plugin_handler.sh add_user $TMPFILE &> /dev/null");
    return $USER->{dn};
}

#-----------------------------------------------------------------------

=item B<delete(dn)>

Delets an user. Removes him from all groups, deletes his mail boxes, and sieve entries.

EXAMPLE:

 $oss->delete('uid=micmou,ou=people,dc=schule,dc=de');

=cut

sub delete($)
{
    my $this = shift;
    my $dn = shift;

    my $uid         = get_name_of_dn($dn);
    my $uidnumber   = $this->get_attribute($dn,'uidnumber');
    my $homedir     = $this->get_attribute($dn,'homedirectory');
    my $school_base = $this->get_school_base($dn);
    my $home_base   = '/home';
    if( $school_base ne $this->{LDAP_BASE} )
    {
      $home_base = $this->get_school_config('SCHOOL_HOME_BASE',$school_base);
    }  
    #First we start the plugins:
    my @attrs = @userAttributes;
    push @attrs, 'group';
    my $TMP = hash_to_text({ $dn , $this->get_user($dn,\@attrs)}); chomp $TMP;
    my $TMPFILE = write_tmp_file($TMP);
    system("/usr/share/oss/plugins/plugin_handler.sh del_user $TMPFILE &> /dev/null");

    if( defined $this->{IMAP} )
    {
	#First we clean up the mail system
	$this->{IMAP}->setacl("user/$uid",'cyrus','lrswipcda');
	$this->{IMAP}->delete("user/$uid");
	#Now we clean up sieve
	$this->connect_sieve($uid);
	$this->{SIEVE}->deleteScript('filter.sieve');
    }

    #delete webdav share
    $this->make_delete_user_webdavshare( "$dn", "0" );

    #Now we delets the user from the groups.
    foreach my $group ( @{$this->get_groups_of_user($dn,1)} )
    {
      $this->delete_user_from_group($dn,$group);
    }


    #Now we deletes the files created by the user;
    system("/usr/share/oss/tools/oss_del_user_files --uid=$uid --uidnumber=$uidnumber --startpath=$home_base --homedir=$homedir");

    #Now we delets the LDAP-entries of the user
    $this->delete_ldap_children($dn);
    $this->{LDAP}->delete($dn);

}
#-----------------------------------------------------------------------
=item B<modify(\%USER)>

Modify an user. The attribute is referenc to a hash containing the changes. 
Some attributes get special handling:

  * dn			  Contains the dn of the user
  * quota		  Mailquota in MB. 0 means no quota.
  * fquota		  Filesystem quota in MB. 0 means no quota.
  * mailAcceptAddress	  This attribute is a list of the addresses which must be deleted
  * newMailAcceptAddress  This is attribute is a list of new email addresses.
  * mailForwardAddress	  This attribute is a list of the addresses which must be deleted
  * newMailForwardAddress This is attribute is a list of new email addresses.

EXAMPLE:

 $oss->modify( { dn => 'uid=micmou,ou=people,dc=schule,dc=de' ,  description => 'The best Student of the World' } );

=cut


sub modify
{
    my $this = shift;
    my $user = shift;
    my $old  = $this->get_entry($user->{dn},1);
    my $attr = $user->{dn}."\n";
    foreach my $i ( keys %{$user} )
    {
	if( $i eq 'webdav_access'){
	    $this->make_delete_user_webdavshare( "$user->{dn}", "$user->{webdav_access}" );
	    next;
	}
	#Handle some special attributes.
	if( $i eq 'quota' )
	{
	    $this->set_quota($user->{dn},$user->{quota});
	    $attr .= 'quota '.$user->{quota}."\n";
	    next;
	}
	if( $i eq 'fquota' )
	{
	    $this->set_fquota($user->{dn},$user->{fquota});
	    $attr .= 'fquota '.$user->{fquota}."\n";
	    next;
	}
	if( $i =~ /^rasaccess$/i )
	{
	    foreach($old->get_value($i))
	    {
	    	$old->delete( $i => $_ ) ;
	    	$attr .= "delete  $_\n";
	    }
	    foreach(@{$user->{$i}})
	    {
	    	$attr .= "add  $_\n";
	    	$old->add( $i => $_ );
	    }
	    next;
	}
	if( $i =~ /^new(.*Address)$/i )
	{
	    my $newattr = $1;
	    if( check_email_address($user->{$i}->[0]) ){
		if( $newattr =~ /mailForwardAddress/i || ( $this->{SYSCONFIG}->{SCHOOL_ALLOW_MULTIPLE_ALIASES} eq 'yes' || $this->is_unique($user->{$i}->[0],'mail') ) )
		{
			$old->add( $newattr => $user->{$i}->[0] );
		    	$attr .= "add $newattr ".$user->{$i}->[0]."\n";
		}
	    }
	    next;
	}
	if( $i =~ /^suse.*Address|mail.*Address$/i )
	{
	    $old->delete( $i => $user->{$i} ) if ( scalar @{$user->{$i}} );
	    foreach(@{$user->{$i}})
	    {
	    	$attr .= "delete $i $_\n";
	    }
	    next;
	}
	if( $i eq 'admin' )
	{
	    my $r = $old->get_value('role');
	    if( $user->{$i} )
	    {
		$this->add_user_to_group($user->{dn},$this->get_primary_group('sysadmins'));
	    	next if( $r =~ /sysadmins/ );
		$old->replace( role => $r.',sysadmins' );
	    	$attr .= "add admin\n";
	    }
	    else
	    {
	    	if( $r =~ s/,sysadmins// )
		{
		    $old->replace( role => $r );
		    $this->delete_user_from_group($user->{dn},$this->get_primary_group('sysadmins'));
	    	    $attr .= "delete admin\n";
		}
	    }
	    next;
	}
	if( $i eq 'group' )
	{
	    foreach(@{$user->{$i}})
	    {
	    	$this->delete_user_from_group($user->{dn},$_);
		$attr .= "delete group $_\n";
	    }
	    next;
	}
	if( $i eq 'newgroup' )
	{
	    foreach(@{$user->{$i}})
	    {
	    	$this->add_user_to_group($user->{dn},$_);
		$attr .= "add group $_\n";
	    }
	    next;
	}
	next if ( !is_user_ldap_attribute($i) );
	if( $old->exists($i) )
	{
	    if( $user->{$i} eq '' )
	    {
	        $old->delete( $i => [] );
		$attr .= "delete $i\n";
		next;
	    }
	    my $tmp = $old->get_value($i);
	    if( $tmp ne $user->{$i} )
	    {
	        $old->replace( $i => $user->{$i} );
	    	$attr .= "replace $i ".$user->{$i}."\n";
	    }
	}
	else
	{
	    if( $user->{$i} )
	    {
	        $old->add( $i => $user->{$i} );
		$attr .= "add $i ".$user->{$i}."\n";
	    }
	}
    }
    $old->update( $this->{LDAP} );
    print Dumper($old)  if ($this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes');
    print Dumper($attr) if ($this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes');
#TODO This is the realy good solution but if no
# changes we get a log of error
#    my  $mesg = $old->update( $this->{LDAP} );
#    if( $mesg->code() )
#    {
#        $this->ldap_error($mesg);
#        return 0;
#    }
    my $TMPFILE = write_tmp_file($attr);
    system("/usr/share/oss/plugins/plugin_handler.sh modify_user $TMPFILE &> /dev/null");
    return 1;
}

sub make_delete_user_webdavshare
{
	my $this          = shift;
	my $user_dn       = shift;
	my $webdav_access = shift || 0;

	my $user_uid = $this->get_attribute( $user_dn, 'uid' );
	my $user_homeDirectory  = $this->get_attribute( $user_dn, 'homeDirectory' );
	my $WebDavAccess_values = $this->get_vendor_object( $user_dn, 'EXTIS', 'WebDavAccess');
	if( defined $WebDavAccess_values->[0]){
		$this->modify_vendor_object( $user_dn, 'EXTIS', 'WebDavAccess', "$webdav_access" );
	}else{
		$this->create_vendor_object( $user_dn, 'EXTIS', 'WebDavAccess', "$webdav_access" );
	}

	if( !(-e "/var/lib/dav")){
		system("mkdir /var/lib/dav/");
		system("chown wwwrun:www /var/lib/dav/");
	}

	if( $webdav_access )
	{
		my $user_uid_lc = lc("$user_uid");
		system("setfacl -PRm  u:wwwrun:rwx $user_homeDirectory/");
		system("setfacl -PRdm u:wwwrun:rwx $user_homeDirectory/");
		system("setfacl -PRdm u:$user_uid:rwx $user_homeDirectory/");
		my $file_content = "Alias /webdav/u/$user_uid_lc \"$user_homeDirectory/\"\n".
				"<IfModule mod_dav_fs.c>\n".
				"        DAVLockDB /var/lib/dav/lockdb\n".
				"<Directory $user_homeDirectory/>\n".
				"        Options All -FollowSymLinks\n".
				"        AllowOverride All\n".
				"        Order deny,allow\n".
				"        Allow from all\n".
				"        Dav On\n".
				"        AuthType Basic\n".
				"        AuthName \"webdav\"\n".
				"        AuthBasicProvider ldap\n".
				"        AuthzLDAPAuthoritative on\n".
				"        AuthLDAPURL ldap://localhost/$this->{LDAP_BASE}?uid??(objectclass=schoolAccount)\n".
				"        Require user $user_uid\n".
				"</Directory>\n".
				"</IfModule>\n";
		write_file("/etc/apache2/vhosts.d/oss-ssl/$user_uid.conf",$file_content);
		system( "rcapache2 reload");
	}
	elsif( (!$webdav_access) and (-e "/etc/apache2/vhosts.d/oss-ssl/$user_uid.conf") )
	{
		system( "rm /etc/apache2/vhosts.d/oss-ssl/$user_uid.conf" );
		system( "setfacl -PRx  u:wwwrun $user_homeDirectory/");
		system( "setfacl -PRdx u:wwwrun $user_homeDirectory/");
		system( "setfacl -PRdx u:$user_uid $user_homeDirectory/");
		system( "rcapache2 reload");
	}

	return 1;
}
