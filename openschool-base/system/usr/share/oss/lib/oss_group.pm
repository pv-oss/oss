=head1 NAME
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

 oss_group

=head1 PREFACE

 This package is the public perl API to configure the OpenSchoolServer.

=head1 SYNOPSIS

 #!/usr/bin/perl 
 
 BEGIN{ push @INC,"/usr/share/oss/lib/"; }
 
 use oss_group;

 my $oss_group = oss_group->new();
 
 $oss_group->delete('uid=micmou,ou=people,dc=schule,dc=de');

=head1 DESCRIPTION

B<oss_group>  is a collection of functions that implement a OpenSchoolServer 
configuration API for Perl programs to add, modify, search and delete group.

=over 2

=cut

BEGIN{
  push @INC,"/usr/share/oss/lib/";
}

package oss_group;

use strict;
use oss_base;
use oss_utils;
use oss_LDAPAttributes;
use Net::LDAP;
use Net::LDAP::Entry;
use Net::IMAP;
use Crypt::SmbHash;
use Time::Local;
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

=item B<add(GroupHash)>

Create a group and returns the dn of the new group. The only parameter is a pointer to 
an hash containig the group attributes. 

IMPORTANT: The hash keys must be in lower case.

EXAMPLE:

   $oss_group = oss_group->new();
   $oss_group->add(     cn  => 'teachers', 
			groupType => 'primary',
			description => 'LehrerInen',
			quota => 50,
			fquota => 500
                );

All LDAP-attributes of the objectclasses
Spetial attributes (hash keys):

=cut

sub add($)
{
    my $this     = shift;
    my $GROUP    = shift;
    my $ERR      = '';

    # Check if the ldap attributes are OK
    $ERR = check_group_ldap_attributes($GROUP);
    if($ERR ne '' )
    {
        $this->{ERROR}->{text}  = $ERR;
        $this->{ERROR}->{code}  = 'BAD-GROUP-ATTRIBUTES';
        return undef;
    }

    #There is a school defined
    if( defined $GROUP->{oid} )
    {
        $this->init_sysconfig($this->get_school_base($GROUP->{oid}));
    }
    if( defined $GROUP->{sDN} )
    {
        $this->init_sysconfig($GROUP->{sDN});
    }
    
    # Prepare the attibutes for cn
    $GROUP->{prefix}  = uc($this->{SYSCONFIG}->{SCHOOL_GROUP_PREFIX}) || '';
    $GROUP->{cn}      = uc($GROUP->{cn});

    # Create the DN of the group entry
    $GROUP->{dn} = 'cn='.$GROUP->{prefix}.$GROUP->{cn};
    $GROUP->{dn} .= ','.$this->{SYSCONFIG}->{GROUP_BASE};
    # Now we create the gidnumber
    if( ! defined $GROUP->{gidnumber} )
    {
        $GROUP->{gidnumber} = $this->get_next_unique('group');
    }

    # Inherit the attributes from %defaultGroup
    foreach my $i ( @groupAttributesToInherit )
    {
        if( defined $defaultGroup{$i} && ! defined $GROUP->{$i})
        {
            if( scalar @{$defaultGroup{$i}} > 1 )
            {
                $GROUP->{$i} = $defaultGroup{$i};
            }
            else
            {
                $GROUP->{$i} = $defaultGroup{$i}->[0];
            }
        }
    }

    #Now we set the samba attributes
    if( ! $this->set_samba_attributes($GROUP) )
    {
	print STDERR "set_samba_attributes error\n";
	print STDERR Dumper($GROUP);
        return undef;
    }

    #Set the mail attributes
    if( !$GROUP->{role}  || $GROUP->{role} ne 'templates' )
    {
        $GROUP->{susemailcommand}       = '"|/usr/bin/procmail -t -m /etc/imap/procmailrc '.utf7_encode($GROUP->{prefix}.$GROUP->{cn}).'"';
        $GROUP->{susemailacceptaddress} = string_to_ascii($GROUP->{cn}).'@'.$this->{SYSCONFIG}->{SCHOOL_DOMAIN};
	push @{$GROUP->{objectclass}}, 'susemailrecipient' if( ! contains( 'susemailrecipient', $GROUP->{objectclass} ));
    }

    #Set some helper parameter
    $GROUP->{shareddir} = $this->{SYSCONFIG}->{SCHOOL_HOME_BASE}.'/groups/'.$GROUP->{cn};
    if( $GROUP->{grouptype} eq 'primary' )
    {
        $GROUP->{basedir} = $this->{SYSCONFIG}->{SCHOOL_HOME_BASE}.'/'.$GROUP->{role};
    }
    if( $GROUP->{grouptype} eq 'class' && $this->{SYSCONFIG}->{SCHOOL_TEACHER_OBSERV_HOME} eq 'yes' )
    {
        $GROUP->{classdir} = $this->{SYSCONFIG}->{SCHOOL_HOME_BASE}.'/classes/'.$GROUP->{cn};
    }
    # If there are no member we put the rootdn in this group
    if( ! $GROUP->{member} )
    {
    	$GROUP->{member} = 'cn=Administrator,'.$this->{LDAP_BASE};
    }
    else
    {
	$this->{LDAP}->modify($GROUP->{member}, add => { OXGroupID => $GROUP->{gidnumber} });
    }
    # Convert boolean to yes/no
    $GROUP->{susedeliverytofolder} = $GROUP->{susedeliverytofolder} ? 'yes' : 'no';
    $GROUP->{susedeliverytomember} = $GROUP->{susedeliverytomember} ? 'yes' : 'no';

    # Now we create an emtpy LDAP entry
    my $GROUPEntry= Net::LDAP::Entry->new();
    $GROUPEntry->dn( $GROUP->{dn} );

    # Now we set the group attributes
    $GROUP->{cn} = $GROUP->{prefix}.$GROUP->{cn};

    # Test if cn and description of group are unique
    if( ! $this->is_unique($GROUP->{cn},'cn'))
    {
	    $this->{ERROR}->{code} = 'GROUP-ALREADY-EXISTS';
	    $this->{ERROR}->{text} = 'The group exists already.';
	    return 0;
    }
    if( defined $GROUP->{description} && $GROUP->{description} ne '' && ! $this->is_unique($GROUP->{description},'description',$this->{SCHOOL_BASE}))
    {
	    print STDERR "GROUP: ".Dumper($GROUP);
	    $this->{ERROR}->{code} = 'GROUP-DESCRIPTION-ALREADY-EXISTS';
	    $this->{ERROR}->{text} = 'The group description exists already.';
	    return 0;
    }

    print "GROUP: ".Dumper($GROUP) if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' );
    print "GROUPEntry: ".Dumper($GROUPEntry) if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' );
    foreach my $i ( keys %{$GROUP} )
    {
        if( is_group_ldap_attribute($i) )
        {
            $GROUPEntry->add( $i => $GROUP->{$i} );
        }
    }
    #Now we are ready we create the entry
    my $mesg = $GROUPEntry->update( $this->{LDAP} );
    if( $mesg->code() )
    {
	print STDERR "GROUP: ".Dumper($GROUP);
	print STDERR "GROUPEntry: ".Dumper($GROUPEntry);
        $this->ldap_error($mesg);
        return 0;
    }

    #Now we create the group directories.
    #Application groups do not get shared folders this exist only in LDAP
    if( $GROUP->{grouptype} ne 'application' )
    {
	my $command = 'mkdir -p '.$GROUP->{shareddir}.'; chgrp '.$GROUP->{gidnumber}.' '.$GROUP->{shareddir}.'; setfacl -d -m g::rwx '.$GROUP->{shareddir}."\n";
	$command .= 'chmod 2771 '.$GROUP->{shareddir}.'; ';
	if( defined $GROUP->{basedir} )
	{
	    $command .= 'mkdir -p -m 751 '.$GROUP->{basedir}.'; chgrp '.$GROUP->{gidnumber}.' '.$GROUP->{basedir}."\n";
	}
	if( defined $GROUP->{classdir} )
	{
	    $command .= 'mkdir -p -m 750 '.$GROUP->{classdir}.'; chgrp '.$GROUP->{prefix}.'teachers '.$GROUP->{classdir}."\n";
	}
	if( $GROUP->{fquota} )
	{
	    my $fquota = 1024 * $GROUP->{fquota};
	    $command .= '/usr/sbin/setquota -g '.$GROUP->{gidnumber}." $fquota $fquota 0 0 -a\n";
	}
	if( $GROUP->{web} )
	{
	   $command .= 'setfacl -m u:wwwrun:x '.$GROUP->{shareddir}.'; mkdir -p -m 755 '.$GROUP->{shareddir}.'/public_html; chgrp '.$GROUP->{gidnumber}.' '.$GROUP->{shareddir}.'/public_html;'; 
	   my $conf = "Alias /".$GROUP->{cn}." ".$GROUP->{shareddir}."/public_html\n".
	              "<Directory ".$GROUP->{shareddir}."/public_html>\n".
	              "   Options +Indexes -FollowSymLinks\n".
	              "   AllowOverride None\n".
	              "   Order allow,deny\n".
	              "   Allow from all\n".
	              "</Directory>\n";
	   write_file('/etc/apache2/vhosts.d/'.$GROUP->{cn}.'.group',$conf);
	}
	system( $command );
	
	#group webdav share
	if($GROUP->{webdav_access}){
	    $this->make_delete_group_webdavshare( "$GROUP->{dn}", "$GROUP->{webdav_access}" );
	}

	if ( ! $this->create_mbox($GROUP->{dn},$GROUP) )
	{
		open(OUT,">/var/adm/OSS-TODO");
		print OUT 'FAILED-ACTION:'.xml_time();
		print OUT "MODUL: oss_group\n";
		print OUT "ACTION: ADD\n";
		print OUT "FUNTION: create_mbox\n";
		print OUT "LINE: __LINE__\n";
		print OUT "SOLVED\n";
		print OUT 'OBJECT:'.Dumper($GROUP);
		print OUT "================================\n";
		close(OUT);
	}
    }
    #Now we start the plugins
    print "Create plugin attributes\n"  if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' );
    my $attrs = '';
    foreach my $i ( keys %{$GROUP} )
    {
        if( $GROUP->{$i} =~ /^ARRAY/ )
        {
            foreach my $j ( @{$GROUP->{$i}} )
            {
                $attrs .= $i.' '.$j."\n";
            }
        }
        else
        {
            $attrs .= $i.' '.$GROUP->{$i}."\n";
        }
    }
    print $attrs if( $this->{SYSCONFIG}->{SCHOOL_DEBUG} eq 'yes' );
    my $TMPFILE = write_tmp_file($attrs);
    system("/usr/share/oss/plugins/plugin_handler.sh add_group $TMPFILE &> /dev/null");
    return $GROUP->{dn};
}

=item B<delete(dn)>

Delets a group. Removes his mail box group directory and LDAP-Entries.

EXAMPLE:

 $oss_group = oss_group->new();
 $oss_group->delete('cn=1008-teachers,ou=group,uniqueIdentifier=1008,dc=realschule-bayern,dc=info');

=cut

sub delete($)
{
    my $this = shift;
    my $dn = shift;

    #First we start the plugins:
    my $TMP = hash_to_text({ $dn , $this->get_group($dn)});
    chomp $TMP;
    my $TMPFILE = write_tmp_file($TMP);
    system("/usr/share/oss/plugins/plugin_handler.sh del_group $TMPFILE &> /dev/null");

    my $cn          = get_name_of_dn($dn);
    my $gidnumber   = $this->get_attribute($dn,'gidnumber');
    my $grouptype   = $this->get_attribute($dn,'grouptype');
    my $school_base = $this->get_school_base($dn);
    my $values      = $this->get_attributes($dn,['member']);
    my @member      = ();
    if( defined $values)
    {
        @member = @{$values->{member}};
    }
    my $prefix      = $this->get_school_config('SCHOOL_GROUP_PREFIX', $this->{SCHOOL_BASE}) || '';
    my $homebase    = $this->get_school_config('SCHOOL_HOME_BASE', $this->{SCHOOL_BASE});
    my $cnhome      = $cn;

    if( $grouptype eq 'primary' && $#member > 1 )
    {
      $this->{ERROR}->{text} = "ERROR Can not delete Primary group if it contains members\n";
      return undef;
    }

    if( $prefix ne '' )
    {
      $cnhome =~ s/^$prefix//;
    }

    $this->make_delete_group_webdavshare( "$dn", "0" );

    if( $cnhome ne '' && $homebase ne '' )
    {
      system("rm -r $homebase/groups/$cnhome");
    }

    if( defined $this->{IMAP} )
    {
        $this->{IMAP}->delete($cn);
    }

    foreach my $udn (@member)
    {
      $this->{LDAP}->modify($udn, delete => { OXGroupID => $gidnumber });
    }

    $this->delete_ldap_children($dn);

    $this->{LDAP}->delete($dn);

}
#-----------------------------------------------------------------------

=item B<modify(%GROUP)>

Modify a group. The attribute is referenc to a hash containing the changes. 
Some attributes get special handling:

  * dn                    Contains the dn of the group
  * quota                 Mailquota in MB. 0 means no quota.
  * fquota                Filesystem quota in MB. 0 means no quota.
  * mailAcceptAddress     This attribute is a list of the addresses which must be deleted
  * newMailAcceptAddress  This is attribute is a list of new email addresses.
  * mailForwardAddress    This attribute is a list of the addresses which must be deleted
  * newMailForwardAddress This is attribute is a list of new email addresses.

EXAMPLE:

 $oss->modify({ dn => 'cn=10A,ou=groups,dc=schule,dc=de', description => 'The best Class of the world' });

=cut

sub modify
{
    my $this  = shift;
    my $group = shift;
    my $old   = $this->get_entry($group->{dn},1);
    my $attr  = $group->{dn}."\n";
    my @member_to_remove;
    my @new_member;
    foreach my $i ( keys %{$group} )
    {
        next if ( "role" eq "$i" );
	#group webdav share
	if($i eq "webdav_access"){
		$this->make_delete_group_webdavshare( "$group->{dn}", "$group->{webdav_access}" );
                next;
	}
        #Handle some special attributes.
        if( $i eq 'quota' )
        {
            $this->set_quota_group($group->{dn},$group->{quota});
            $attr .= 'quota '.$group->{quota}."\n";
            next;
        }
        if( $i eq 'fquota' )
        {
            $this->set_fquota_group($group->{dn},$group->{fquota});
            $attr .= 'quota '.$group->{fquota}."\n";
            next;
        }
        if( $i =~ /^newmember$/i )
        {
            foreach(@{$group->{$i}})
            {
                $attr .= 'add member '.$_."\n";
		push @new_member, $_;
            }
            next;
        }
        if( $i =~ /^member$/i )
        {
            foreach(@{$group->{$i}})
            {
                $attr .= 'delete member '.$_."\n";
		push @member_to_remove, $_;
            }
            next;
        }
        if( $i =~ /^newsusemailAcceptAddress|newmailAcceptAddress$/i )
        {
            if( check_email_address($group->{$i}->[0]) ){
                $old->add( susemailAcceptAddress => $group->{$i} ) if( scalar @{$group->{$i}} );
                foreach(@{$group->{$i}})
                {
                     $attr .= 'add susemailAcceptAddress '.$_."\n";
                }
	    }
            next;
        }
        if( $i =~ /^susemailAcceptAddress|mailAcceptAddress$/i )
        {
            $old->delete( susemailAcceptAddress => $group->{$i} ) if( scalar @{$group->{$i}} );
            foreach(@{$group->{$i}})
            {
                $attr .= 'delete susemailAcceptAddress '.$_."\n";
            }
            next;
        }
        if( $i =~ /^newsusemailForwardAddress|newmailForwardAddress$/i )
	{
	    if( check_email_address($group->{$i}->[0]) ){
                $old->add( susemailForwardAddress => $group->{$i} ) if( scalar @{$group->{$i}} );
                foreach(@{$group->{$i}})
                {
                     $attr .= 'add susemailForwardAddress '.$_."\n";
                }
	    }
            next;
        }
        if( $i =~ /^susemailForwardAddress|mailForwardAddress$/i )
        {
            $old->delete( susemailForwardAddress => $group->{$i} )  if( scalar @{$group->{$i}} );
            foreach(@{$group->{$i}})
            {
                $attr .= 'delete susemailForwardAddress '.$_."\n";
            }
            next;
        }
        if( $i =~ /^suseDeliveryTo/i )
        {
		$group->{$i} = $group->{$i} ? 'yes' : 'no';	
	}
        next if ( !is_group_ldap_attribute($i) );
        if( $old->exists($i) )
        {
            if( $group->{$i} eq '' )
            {
                $old->delete( $i => [] );
                $attr .= "delete $i\n";
                next;
            }
            my $tmp = $old->get_value($i);
            if( $tmp ne $group->{$i} )
            {
                $old->replace( $i => $group->{$i} );
                $attr .= "replace $i ".$group->{$i}."\n";
            }
        }
        else
        {
            if( $group->{$i} )
            {
                $old->add( $i => $group->{$i} );
                $attr .= "add $i ".$group->{$i}."\n";
            }
        }
    }
    $old->update( $this->{LDAP} );

    #now we remove and add the member
    foreach(@member_to_remove)
    {
    	$this->delete_user_from_group($_,$group->{dn});
    }
    foreach(@new_member)
    {
    	$this->add_user_to_group($_,$group->{dn});
    }
    my $TMPFILE = write_tmp_file($attr);
    system("/usr/share/oss/plugins/plugin_handler.sh modify_group $TMPFILE &> /dev/null");
    return 1;
}

sub make_delete_group_webdavshare
{
	my $this          = shift;
	my $group_dn      = shift;
	my $webdav_access = shift || 0;

	my $group_cn = $this->get_attribute( $group_dn, 'cn' );
	my $WebDavAccess_values = $this->get_vendor_object( $group_dn, 'EXTIS', 'WebDavAccess');
	if( defined $WebDavAccess_values->[0]){
		$this->modify_vendor_object( $group_dn, 'EXTIS', 'WebDavAccess', "$webdav_access" );
	}else{
		$this->create_vendor_object( $group_dn, 'EXTIS', 'WebDavAccess', "$webdav_access" );
	}

	if( !(-e "/var/lib/dav")){
		system("mkdir /var/lib/dav/");
		system("chown wwwrun:www /var/lib/dav/");
	}

	if( $webdav_access )
	{
		my $group_cn_lc = lc("$group_cn");
		system("setfacl -PRm  u:wwwrun:rwx /home/groups/$group_cn/");
		system("setfacl -PRdm u:wwwrun:rwx /home/groups/$group_cn/");
		my $file_content = "Alias /webdav/g/$group_cn_lc \"/home/groups/$group_cn/\"\n".
				"<IfModule mod_dav_fs.c>\n".
				"        DAVLockDB /var/lib/dav/lockdb\n".
				"<Directory /home/groups/$group_cn/>\n".
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
				"        Require ldap-group $group_dn\n".
				"</Directory>\n".
				"</IfModule>\n";
		write_file("/etc/apache2/vhosts.d/oss-ssl/$group_cn.conf",$file_content);
		system( "rcapache2 reload");
	}
	elsif( (!$webdav_access) and (-e "/etc/apache2/vhosts.d/oss-ssl/$group_cn.conf"))
	{
		system( "rm /etc/apache2/vhosts.d/oss-ssl/$group_cn.conf" );
		system( "setfacl -PRx  u:wwwrun /home/groups/$group_cn/");
		system( "setfacl -PRdx u:wwwrun /home/groups/$group_cn/");
		system( "rcapache2 reload");
	}

	return 1;
}

