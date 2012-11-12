=head1 NAME
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

 oss

=head1 PREFACE

 This package is the public perl API to configure the OpenSchoolServer.

=head1 SYNOPSIS

 #!/usr/bin/perl 
 
 BEGIN{ push @INC,"/usr/share/oss/lib/"; }
 
 use oss_base;
 
 my $uid           = shift;
 my $userpassword  = shift;
 my $remote        = shift || '';
 my $oid           = shift || '';
 my $dn;
 my $reply;

 my $oss = oss_base->new();
 
 if( $oid ne '' ) {
   my $sdn = $oss->get_school_base($oid);
   $dn = $oss->get_user_dn($uid,$sdn);
 } else {
   $dn = $oss->get_user_dn($uid);
 }
 
 if($remote eq '' ) {
   $reply = $oss->login($dn,$userpassword,0);
 } else {
   $reply = $oss->login($dn,$userpassword,1,$remote);
 }
 
 if( $reply ) {
   print $oss->reply($reply);
 } else {
   die ($oss->{ERROR}->{text});
 }

=head1 DESCRIPTION

B<oss>  is a collection of functions that implement a OpenSchoolServer 
configuration API for Perl programs.

=over 2

=cut

BEGIN{ 
  push @INC,"/usr/share/oss/lib/"; 
}

package oss_base;

use strict;
use oss_utils;
use oss_LDAPAttributes;
use Net::LDAP;
use Net::LDAP::Util qw( ldap_error_name ldap_error_text) ;
use Net::LDAP::Entry;
use Net::IMAP;
use Net::Netmask;
use Socket;
use Time::Local;
use Digest::MD5  qw(md5_hex);
use ManageSieve;
use MIME::Base64;
use Crypt::SmbHash;
use Storable qw(thaw freeze);
use POSIX qw(strftime);
use Quota;

# The standard output format is XML
# Debug only
use Data::Dumper;

#######################################################################################
# End header									      #
#######################################################################################

#######################################################################################
# Basic Utilities								      #
#######################################################################################

=item B<new()>

The Constructor of an oss object

EXAMPLE:

  my $oss = oss->new();

=cut

sub new
{
    my ($this, $connect)     = @_;
    my $class    = ref($this) || $this;
    my $self     = {};
    bless $self, $class;
    $self->{XML} = 1;
    $self->{DEFAULT_USER_ATTRIBUTES} = [
                'admin',
                'birthday',
                'c',
		'cn',
                'facsimiletelephonenumber',
                'fquota',
                'gidnumber',
                'givenname',
                'group',
                'homephone',
                'jpegphoto',
                'l',
                'labeleduri',
                'mail',
                'mobile',
                'ou',
                'oxtimezone',
                'postalcode',
                'preferredlanguage',
                'quota',
                'religion',
                'role',
                'sn',
                'st',
                'street',
                'susemailacceptaddress',
                'susemailforwardaddress',
                'telephonenumber',
                'title',
                'uid',
                'uidnumber'

	];
    $self->{DEFAULT_GROUP_ATTRIBUTES} = [
                'cn',
                'deliverytofolder',
                'deliverytomember',
                'description',
                'fquota',
                'gidNumber',
                'grouptype',
                'mboxacl',
                'member',
                'quota',
                'role',
                'susemailforwardaddress',
                'writerdn'
	];

    foreach my $k ( keys %{$connect} )
    {
    	$self->{$k} = $connect->{$k};
    }

    if( defined $connect->{LDAP_CONF} && $connect->{LDAP_CONF} ne '' )
    {
      $self->{LDAP_CONF} = $connect->{LDAP_CONF};
    }
    else
    {
      $self->{LDAP_CONF} = '/etc/ldap.conf';
    }

    $self->connect_ldap('anon') || return undef;

    if( defined $connect->{aDN} && $connect->{aDN} eq 'anon' )
    {
	if( defined $connect->{sDN} )
	{
		$self->{SCHOOL_BASE} = $connect->{sDN};
        	$self->init_sysconfig();
	}
	else
	{
        	$self->init_sysconfig('file');
	}
    }
    elsif( ( defined $connect->{aUID} ) || ( defined $connect->{aDN} ))
    {
        if( defined $connect->{aOID} )
        {
           $connect->{sDN} = $self->get_school_base($connect->{aOID}); 
        }
        if( defined $connect->{aUID} )
        {
           $connect->{aDN}      = $self->get_user_dn($connect->{aUID},$connect->{sDN});
        }   
	if( ! defined $connect->{sDN} )
	{
	   $connect->{sDN} = $self->get_school_base($connect->{aDN});
	}
	$self->{SCHOOL_BASE} = $connect->{sDN};
        $self->init_sysconfig();
        if( ! $self->login($connect->{aDN},$connect->{aPW}) )
        {
	   print STDERR $this->{ERROR}->{text};
           return undef;
        }
	if( $self->is_admin($connect->{aDN}))
	{
        	$self->connect_imap('admin');
	}
	else
	{
        	$self->connect_imap(get_name_of_dn($connect->{aDN}),$connect->{aPW});
	}
    }
    else
    {
        $self->init_sysconfig('file');    
	$self->{LDAP}->unbind;
	$self->{LDAP} = undef;
        $self->connect_ldap('admin') || return undef;
        $self->connect_imap('admin');
    }
    return $self;
}
#-----------------------------------------------------------------------

=item B<destroy()>

The destructor of an oss object

EXAMPLE:

  my $oss = oss->destroy();

=cut

sub destroy
{
    my $this   = shift;
    if( defined $this->{LDAP} )
    {
      $this->{LDAP}->unbind();
    }
    if( defined $this->{IMAP} )
    {
      $this->{IMAP}->logout();
    }
    if( defined $this->{SIEVE} )
    {
      $this->{SIEVE}->logout();
    }
    $this = {};
    return 1;
}
#-----------------------------------------------------------------------

=item B<connect_imap(user, userpassword)>

Make an IMAP connection.

EXAMPLE:

  $oss->connect_imap();

  Makes an IMAP-connection as user C<cyrus>. Works only if the program will be executed with root rights.

  $oss->connect_imap('varkpete','12345678');

  Makes an IMAP-connection as user C<varkpete>. 

=cut

sub connect_imap()
{
    my $this     = shift;
    my $user     = shift || 'cyrus';
    my $password = shift || '';

    return if( ! $this->{withIMAP} );
    # Zarafa do not need IMAP
    return if( defined $this->{SYSCONFIG}->{SCHOOL_USE_ZARAFA} && $this->{SYSCONFIG}->{SCHOOL_USE_ZARAFA} eq 'yes' );

    if( $user eq 'admin' )
    {
	$user = 'cyrus';
    }
    if( $user eq 'cyrus' )
    {
      $this->init_admin();
      $password = $this->{APW};
    }
    if( !defined $this->{SYSCONFIG}->{SCHOOL_MAILSERVER} )
    {
      $this->init_sysconfig(); 
    }

    $this->{IMAP} = new Net::IMAP($this->{SYSCONFIG}->{SCHOOL_MAILSERVER}, Debug => 0); 
    if( ! $this->{IMAP} )
    {
      $this->{ERROR}->{text} = "ERROR Could not make IMAP connection to $this->{SYSCONFIG}->{SCHOOL_MAILSERVER}\n";
      return undef;
    }
    if( ! $this->{IMAP}->login($user, $password) )
    {
      $this->{ERROR}->{text} = "ERROR Could not login to the IMAP server $this->{SYSCONFIG}->{SCHOOL_MAILSERVER} as $user\n";
      return undef;
    }
    return 1;
}
#-----------------------------------------------------------------------

=item B<connect_ldap(type, bind_dn, userpassword)>

Initialize the global variable $LDAP.

EXAMPLE:

  $oss->connect_ldap('anon');

  Makes an anonymous LDAP-Connection

  $oss->connect_ldap('admin');

  Makes an  LDAP-Connection with root-DN rigts. Works only if the programm
  will be executed with root rights. In this case the subroutine <init_admin>
  will be called.

  connect_ldap('user','uid=varkpete,ou=people,dc=extis,dc=de','12345678');

  Makes an LDAP-Connection with user-DN rigts. 
   
=cut

sub connect_ldap
{
    my $this     = shift;
    my $type     = shift || 'admin';
    my $dn       = shift || '';
    my $password = shift || '';

    if( defined $this->{LDAP} )
    {
      $this->{ERROR}->{text} = "ERROR LDAP Already connected\n";
      return -1;
    }

    # Searching for LDAP-Server settings
    my ($LDAP_BASE, $LDAP_SERVER, $LDAP_PORT) = parse_file($this->{LDAP_CONF}, "BASE", "HOST", "PORT");
    $LDAP_BASE =~ s/\s*?^(.*)\s*$/$1/i;
    if($LDAP_BASE eq "")
    {
        $this->{ERROR}->{text} = "ERROR Unable to parse ldap.conf or baseDN was not found!\n";
	return 0;
    }
    if($LDAP_SERVER eq "")
    {
        $LDAP_SERVER = "localhost";
    }
    if($LDAP_PORT eq "") 
    {
        $LDAP_PORT = 389;
    }
    $this->{LDAP} = Net::LDAP->new($LDAP_SERVER,port => $LDAP_PORT ,version => 3);
    if( ! $this->{LDAP} )
    {
        $this->{ERROR}->{text} = "Could not make LDAP connection\n";
	return 0;
    }
    if( $type ne 'anon' )
    {
      if( $type eq 'admin' )
      {
        $this->init_admin();
        $dn       = $this->{BIND_DN};
	$password = $this->{APW};
      }
      if( ! $this->{LDAP}->bind($dn, password=>$password) )
      {
        $this->{ERROR}->{text} = "Could not bind LDAP\n";
	return 0;
      }
    }
    $this->{LDAP_BASE}   = $LDAP_BASE;
    $this->{LDAP_SERVER} = $LDAP_SERVER;
    $this->{LDAP_PORT}   = $LDAP_PORT;
    return 1;
}
#-----------------------------------------------------------------------

=item B<connect_sieve(|user)>

Creates an sieve connection. If user is given, a proxy connection will be made.
If not, an admin connection will be made.

EXAMPLE:

  my $oss = oss->new;
  $oss->connect_sieve('micmou');

  Makes a sieve proxy connection as micmou. 
  
  $oss->connect_sieve();

  Makes a sieve connection as cyrus. 
  These both works only if the script will be executed as root.
  
  $oss->connect_sieve('micmou','12345mimou');
  
  Makes a sieve connection as micmou. 

  $oss->{SIEVE}->deleteScript('filter.sieve');

=cut

sub connect_sieve()
{
    my $this     = shift;
    my $user     = shift  || 'cyrus';
    my $password = shift  || '';
    my $port     = 2000;

    if( $user eq 'cyrus' && !defined $this->{APW} )
    {
      $this->init_admin();
    }

    if( !defined $this->{SYSCONFIG}->{SCHOOL_MAILSERVER} )
    {
      $this->init_sysconfig(); 
    }
    if( defined $this->{SYSCONFIG}->{SCHOOL_SIEVEPORT} )
    {
      $port = $this->{SYSCONFIG}->{SCHOOL_SIEVEPORT};
    }

    $this->{SIEVE} = ManageSieve->new($this->{SYSCONFIG}->{SCHOOL_MAILSERVER}  ,$port);
    if( ! $this->{SIEVE}->connect )
    {
      $this->{ERROR}->{text} = "ERROR Could not make SIEVE connection to $this->{SYSCONFIG}->{SCHOOL_MAILSERVER}\n";
      return undef;
    }
    if( $password eq '' )
    {
      $this->init_admin();
      my ($res, $text) = $this->{SIEVE}->authplain($user, 'cyrus', $this->{APW});
      if( $res ne 'OK' )
      {
        $this->{ERROR}->{text} = "ERROR Could not login to the IMAP server $this->{SYSCONFIG}->{SCHOOL_MAILSERVER} as $user\n";
        return undef;
      }
    }
    else
    {
      my ($res, $text) = $this->{SIEVE}->authplain($user, $user, $password);
      if( $res ne 'OK' )
      {
        $this->{ERROR}->{text} = "ERROR Could not login to the IMAP server $this->{SYSCONFIG}->{SCHOOL_MAILSERVER} as $user\n";
        return undef;
      }
    }  
    return 1;
}

#-----------------------------------------------------------------------
# Soubrutines to manipulate basic objects
#-----------------------------------------------------------------------

=item B<create_mbox(name|dn,Propertie-Hash)>

Creates a mailbox with default acls and if given with quota. For users the
default mailboxes will be created too.

EXAMPLE:

    $oss->create_mbox('Test',{ quota => 50 });

    $oss->create_mbox('uid=varkpete,ou=people,dc=extis,dc=de', { quota => 50 });

    $oss->create_mbox('cn=TEACHERS,ou=group,dc=extis,dc=de');

=cut

sub create_mbox($$)
{
    my $this    = shift;
    my $mbox    = shift;
    my $prop    = shift;
    my $quota   = 0 ;
    my $owner   = $mbox;
    my $dn      = undef;
    my $is_user = 0;
    my $acl     = 'lrswipkxtea';
    my @submailboxes  = ('Sent','Trash','Spam','Templates');

    if( defined $this->{SYSCONFIG}->{SCHOOL_USE_ZARAFA}  && $this->{SYSCONFIG}->{SCHOOL_USE_ZARAFA} eq 'yes' )
    {   #TODO What happends with shared mailboxes???
        if( $mbox =~ /^uid=.*/ )
        {
                if( defined $prop->{quota} )
                {
                    $quota = $prop->{quota};
                }
                 $this->{LDAP}->modify( $dn,       add => { zarafaQuotaWarn => int($quota*0.8),
                                                            zarafaQuotaSoft => int($quota),
                                                            zarafaQuotaHard => int($quota*1.1)} );
        }
	return;
    }

    if( $mbox =~ /^uid=.*/ )
    {
    	$dn	 = $owner;
        $owner   = get_name_of_dn($owner);
        $mbox    = 'user/'.utf7_encode($owner);
        $is_user = 1;
    }
    elsif( $mbox =~ /^cn=.*/ )
    {
	if( $this->is_class($mbox) )
	{
		$acl   = $this->get_school_config('SCHOOL_CLASS_FOLDER_RIGHTS') || 'lrswipt';
	}
	else
	{
		$acl   = $this->get_school_config('SCHOOL_GROUP_FOLDER_RIGHTS') || 'lrswipt';
	}
        $mbox  = get_name_of_dn($mbox);
        $owner = 'group:'.$mbox;
	$mbox  = utf7_encode($mbox);
        @submailboxes  = ('spam');
    }

    if( defined $prop->{quota} )
    {
        $quota = $prop->{quota};
    }
    if( defined $prop->{mailbox} )
    {
        @submailboxes = @{$prop->{mailbox}};
    }
    if( ! defined $this->{IMAP} )
    {
	    $this->{ERROR}->{code} = "IMAP-NOT-CONNECTED";
	    $this->{ERROR}->{text} = "The imap server is not connected";
	    return 0;
    }
    $this->{IMAP}->create($mbox);
    $this->{IMAP}->setacl($mbox,"anyone","p");
    $this->{IMAP}->setacl($mbox,$owner,$acl);
    $this->{IMAP}->setacl($mbox,"cyrus","lrswipkxtea");
    if( $quota )
    {
    	my @qarray = ("STORAGE", $quota * 1024 );
	$this->{IMAP}->setquota($mbox,@qarray);
    }
# TODO clear if we realy need it
# This can make big problems by import: creating user/<actuel user>/user/<previous user>    
#    foreach my $smbox ( @submailboxes )
#    {
#	$this->{IMAP}->create($mbox.'/'.$smbox);
#    }
#    if( $is_user && defined $prop->{cleartextpassword} )
#    {
#	$this->{IMAP}->logout();
#    	$this->{IMAP} = new Net::IMAP($this->{SYSCONFIG}->{SCHOOL_MAILSERVER}, Debug => 0); 
#    	if(  $this->{IMAP}->login($owner, $prop->{cleartextpassword}) )
#	{
#		foreach my $smbox ( @submailboxes )
#		{
#			$this->{IMAP}->subscribe($smbox );
#		}
#	}
#    }
}

=item B<delete_ldap_children(dn)>

Delets the children of an LDAP-entry

EXAMPLE:

  $oss->delete_ldap_children('uid=micmou,ou=people,dc=schule,dc=de');

=cut

sub delete_ldap_children($)
{
    my $this = shift;
    my $dn = shift;

    my $mesg = $this->{LDAP}->search( base   => $dn,
    			              scope  => 'one',
			              filter => 'objectclass=*',
			              attrs  => [ 'dn' ]
			            );
    if( $mesg->code )
    {
      $this->ldap_error($mesg);
      return 0;
    }
    foreach my $entry ($mesg->entries)
    {
      if( $this->delete_ldap_children( $entry->dn()) )
      {
        $this->{LDAP}->delete($entry->dn());
      }
      else
      {
        return 0;
      }
    }
    return 1;

}
#-----------------------------------------------------------------------

=item B<move_ldap_entry(dn,new)>

Move entry with the children of an LDAP-entry

EXAMPLE:

  $oss->move_ldap_entry('uid=micmou,ou=people,dc=schule,dc=de','uid=micmou,ou=people,uniqueidentifier=1012,dc=schule,dc=de');

=cut

sub move_ldap_entry($$)
{
    my $this = shift;
    my $dn   = shift;
    my $new  = shift;
    my $odn  = $dn;

    my $mesg = $this->{LDAP}->search( base   => $dn,
                                      scope  => 'one',
                                      filter => 'objectclass=*',
                                      attrs  => [ 'dn' ]
                                    );
    if( $mesg->code )
    {
      $this->ldap_error($mesg);
      return 0;
    }
    my $e   = $this->get_entry($dn,1);
    my $pdn = get_parent_dn($dn);
    $dn  =~ s/$pdn$/$new/;
    $e->dn( $dn );
    $this->{LDAP}->add($e);
    foreach my $entry ($mesg->entries)
    {
        $this->move_ldap_entry( $entry->dn(), $dn );
    }
    $this->{LDAP}->delete($odn);
    return 1;

}

#-----------------------------------------------------------------------

=item B<exists_dn(dn)>

Returns 1 if a dn exists and 0 if not.

EXAMPLE:

   my $user_exist = $oss->exists_dn($dn); 

=cut

sub exists_dn($)
{
  my $this   = shift;
  my $dn     = shift;

  my $mesg = $this->{LDAP}->search( base   => $dn, 
                                    scope  => 'base', 
				    filter => 'objectclass=*',
				    attrs  => []
				  );
  if( $mesg->code || ! $mesg->count )
  {
    $this->{ERROR}->{code} = "DN-DO-NOT-EXIST";
    $this->{ERROR}->{text} = "'$dn' do not exists.";
    return 0;
  }
  return 1;

}
#-----------------------------------------------------------------------

=item B<get_entries_dn(filter,school_dn)>

Delivers the dns of the result of an LDAP search

   my @templates = $oss->get_entries_dn("(role=templates)");

=cut

sub get_entries_dn
{
    my $this        = shift;
    my $filter      = shift;
    my $school_base = shift || $this->{SCHOOL_BASE};
    my @dn          = ();

    my $result = $this->{LDAP}->search( base   => $school_base,
    				      filter => $filter,
				      scope  => 'sub',
				      attrs  => [ 'dn' ]
				    );  
    foreach my $entry ( $result->entries() )
    {
      push @dn, $entry->dn();
    }
    return \@dn;
}

#-----------------------------------------------------------------------

=item B<get_entry(DN,[1])>

Returns an hash result of a DN.
Do not forget that the values of the keys are in array!
If you do not want to get a hash result but an Nett::LDAP::Entry object give 
a second parameter. 

EXAMPLE:

 my $entry = $oss->get_entry(DN-of-the-object);

 print join('',$entry->{'uid'});
 or
 print $entry->{'uid'}->[0];


=cut

sub get_entry
{
    my $this = shift;
    my $dn   = shift;
    my $obj  = shift || undef;

    my $result = $this->{LDAP}->search( base   => $dn,
                                      scope  => 'base',
                                      filter => '(objectclass=*)'
                            );
    if( $obj && $result && $result->count() == 1 )
    {
       return $result->entry(0);
    }
    if( $result && $result->count() == 1)
    {
       my $entry = $result->as_struct;
       return $entry->{$dn};
    }
    return undef;
}

#-----------------------------------------------------------------------

=item B<get_config_value(DN-of-the-object,'KEY')>

Returns an configurations value of a object

EXAMPLE:

 my $VALUE = $oss->get_config_value('cn=edv-pc01,cn=Room0,cn=172.17.0.0,cn=config1,cn=schooladmin,ou=DHCP,dc=EXTIS-School,dc=de','HW');

=cut

sub get_config_value($$)
{
    my $this = shift;
    my $dn   = shift;
    my $key  = shift;

    my $mesg = $this->{LDAP}->search( base   => $dn,
                                      scope  => 'base',
                                      filter => '(objectclass=*)',
                                      attrs  => [ 'configurationValue', 'description' ]
                            );
    if( $mesg && $mesg->count() == 1)
    {
      if( $key eq 'description' )
      {
         return $mesg->entry(0)->get_value('description');
      }
      my @values = $mesg->entry(0)->get_value('configurationValue');
      foreach my $config (@values)
      {
        if( $config =~ /^$key=/i )
        {
	    my ($keyn,$value) = split /=/,$config,2;
            return $value;
        }
      }
    }
    return undef;
}

#-----------------------------------------------------------------------

=item B<set_config_value(DN-of-the-object,'KEY','new value')>

Sets a configurations value of a object

EXAMPLE:

 $oss->set_config_value('cn=edv-pc01,cn=Room0,cn=172.17.0.0,cn=config1,cn=schooladmin,ou=DHCP,dc=EXTIS-School,dc=de','HW','hwconf2');

=cut
sub set_config_value($$$)
{
    my $this      = shift;
    my $dn        = shift;
    my $key       = shift;
    my $value     = shift;

    my $entry     = $this->get_entry( $dn, 1);
    my @configs   = $entry->get_value('configurationValue');
    foreach my $config ( @configs )
    {
        if( $config =~ /^$key=/i )
	{
	    $entry->delete( configurationValue => [ $config ] );
	}
    }
    $entry->add( configurationValue => $key.'='.$value );
    my $mesg = $entry->update( $this->{LDAP} );
    if( $mesg->code() )
    {
	$this->ldap_error($mesg);
	return 0;
    }
    return 1;
}

#-----------------------------------------------------------------------

=item B<get_attribute(dn,attribute)>

Returns an attribute of the object given by the dn. 

EXAMPLE:

  my $homedirectory = $oss->get_attribute('uid=varkpete,ou=people,dc=extis,dc=de','homedirectory');

=cut

sub get_attribute($$)
{
    my $this      = shift;
    my $dn        = shift;
    my $attribute = shift;

    my $mesg = $this->{LDAP}->search( base  => $dn,
                                      scope => 'base',
          		             filter => '(objectclass=*)',
          	                      attrs => [ $attribute ]
    		                 );
    if( $mesg->code() || $mesg->count() != 1 )
    {
      return undef;
    }
    return $mesg->entry(0)->get_value($attribute);
}
#-----------------------------------------------------------------------

=item B<set_attribute(dn,attribute,value)>

Sets an attribute of the object given by the dn to the new value. 

EXAMPLE:

  my $homedirectory = $oss->get_attribute('uid=varkpete,ou=people,dc=extis,dc=de','uidnumber','12345');

=cut

sub set_attribute($$$)
{
    my $this      = shift;
    my $dn        = shift;
    my $attribute = shift;
    my $value     = shift;

    my $entry     = $this->get_entry( $dn, 1);
    if( $entry->exists($attribute) )
    {
    	$entry->replace($attribute => $value );
    }
    else
    {
    	$entry->add($attribute => $value );
    }
    my $mesg = $entry->update( $this->{LDAP} );
    if( $mesg->code() )
    {
	$this->ldap_error($mesg);
	return undef;
    }
    return 1;
}
#-----------------------------------------------------------------------

=item B<get_attributes(dn,attributes)>

Returns attributes of the object given by the dn. The second parameter is a 
pointerr to a array.

EXAMPLE:

  my $attributes = $oss->get_attributes('uid=varkpete,ou=people,dc=extis,dc=de',['homedirectory','uidnumber','gidnumber']);

  print $attributes->{homedirectory}->[0]."\n";
  print $attributes->{uidnumber}->[0]."\n";
  print $attributes->{gidnumber}->[0]."\n";

=cut

sub get_attributes($$)
{
    my $this = shift;
    my $dn         = shift;
    my $attributes = shift;
    my %reply      = ();
    
    my $mesg = $this->{LDAP}->search( base  => $dn,
    		           scope => 'base',
          		   filter=> '(objectclass=*)',
          	           attrs => $attributes
    		);
    if( $mesg->code() || $mesg->count() != 1 )
    {
      return undef;
    }
    foreach my $attribute ( @{$attributes} )
    {
       push @{$reply{$attribute}}, $mesg->entry(0)->get_value($attribute);
    }
    return \%reply;
}
#-----------------------------------------------------------------------

=item B<get_next_unique(user|group)>

Returns the next free unique identifier

EXAMPLE:

  my $uidnumber = $oss->get_next_unique(user);

=cut

sub get_next_unique
{
    my $this = shift;
    my $type = shift || 'user';
    my $base = 'cn='.$type.'configuration,ou=ldapconfig,'.$this->{LDAP_BASE};

    #TODO at the time we only count up;
    my $oldid = $this->get_attribute( $base,'suseNextUniqueid');

    while ( !$this->is_unique($oldid,$type) )
    {
	$oldid ++;
    }
    my $newid = $oldid +1;
    my $mesg = $this->{LDAP}->modify( $base,
		           replace =>  { suseNextUniqueid => "$newid" }
			);
    return $oldid;
}

=item B<set_samba_attributes(Group or User Hash)>

Sets the Required Samba attributes for a user or group

EXAMPLE:

    $oss->set_samba_attributes($USER);

=cut

sub set_samba_attributes($)
{

    my $this   = shift;
    my $OBJECT = shift;

    my $mesg = $this->{LDAP}->search( base   => $this->{SCHOOL_BASE},
                                      filter => "(&(objectclass=sambaDomain)(sambaDomainName=".$this->{SYSCONFIG}->{SCHOOL_WORKGROUP}."))",
                                      scope  => 'sub',
                                      attrs  => [ 'sambaSID','sambaAlgorithmicRidBase' ]
    );
    if( $mesg->code() || $mesg->count() != 1 )
    {
        $mesg = $this->{LDAP}->search( base   => $this->{LDAP_BASE},
                                      filter => "(&(objectclass=sambaDomain)(sambaDomainName=".$this->{SYSCONFIG}->{SCHOOL_WORKGROUP}."))",
                                      scope  => 'sub',
                                      attrs  => [ 'sambaSID','sambaAlgorithmicRidBase' ]
        );
        if( $mesg->code() || $mesg->count() != 1 )
        {
		$this->{ERROR}->{code} = "SAMBA-DOMAIN-NOT-FOUND";
		return undef;
	}
    }
    my $sambaSID =  $mesg->entry(0)->get_value('sambaSID');
    my $sambaAlgorithmicRidBase =  $mesg->entry(0)->get_value('sambaAlgorithmicRidBase');
    if( defined $OBJECT->{role} && $OBJECT->{role} eq 'machine' )
    {
	$OBJECT->{sambaprimarygroupsid} = $sambaSID.'-132069';
    }
    elsif( defined $OBJECT->{grouptype} )
    {
	$OBJECT->{sambagrouptype} = '2';
	$OBJECT->{sambaacctflags}       = "[G          ]" ;
    }
    else
    {
	$OBJECT->{sambaacctflags}       = "[U          ]" ;
	$OBJECT->{sambapasswordhistory} = "0000000000000000000000000000000000000000000000000000000000000000" ;
	if( $OBJECT->{role} eq "workstations" )
	{
	    $OBJECT->{sambauserworkstations} = $OBJECT->{uid} ;
	    $OBJECT->{sambapwdcanchange}     = "2147483647" ;
	}
	my ( $lm, $nt ) = ntlmgen $OBJECT->{userpassword};
        if( defined $OBJECT->{role} && $OBJECT->{role} eq 'machine' )
	{
		( $lm, $nt ) = ntlmgen '12345678';
	}
	$OBJECT->{sambalmpassword}  = $lm ;
	$OBJECT->{sambantpassword}  = $nt ;
    }
    if( ! defined $OBJECT->{SID}  || $OBJECT->{SID} == 0 )
    {
        if( defined $OBJECT->{grouptype} )
	{
        	$OBJECT->{SID} = 2 * $OBJECT->{gidnumber} + $sambaAlgorithmicRidBase + 1;
	}
	else
	{
        	$OBJECT->{SID} = 2 * $OBJECT->{uidnumber} + $sambaAlgorithmicRidBase;
	}
    }
    $OBJECT->{sambasid}             = $sambaSID."-".$OBJECT->{SID};

}
#-----------------------------------------------------------------------

=item B<init_admin()>

Initialize the variable BIND_DN and APW with the system settings.
Works only if the programm will be executed with root rights.

EXAMPLE:

  $oss->init_admin();

  print $oss->{BIND_DN};
  print $oss->{APW};

=cut

sub init_admin
{
    my $this = shift;
    $this->{aDN} = $this->{BIND_DN} =`. /etc/sysconfig/ldap ; echo -n \$BIND_DN;`;
    $this->{aPW} = $this->{APW}     =`/usr/sbin/oss_get_admin_pw`;
}    
#-----------------------------------------------------------------------

=item B<init_sysconfig('file'|dn)>

Reads the configuration of a school into the global hash %this->{SYSCONFIG}->.

EXAMPLE:

  $oss->init_sysconfig('file');

  Reads the variables from the file "/etc/sysconfig/schoolserver".

  $oss->init_sysconfig();

  Reads the variables from LDAP-Server with base "ou=sysconfig,$this->{SCHOOL_BASE}".

  $oss->init_sysconfig('uniqueIdentifier=1008,dc=realschule-bayern,dc=info');

  Reads the variables of the school with the dn from LDAP-Server.


=cut

sub init_sysconfig 
{
    my $this = shift;
    my $dn   = shift;

    my $base = $this->{SCHOOL_BASE}; 

    if( defined $dn && $dn eq 'file')
    {
      open( IN, "/etc/sysconfig/schoolserver" );
      while(<IN>){
        next if (/^#/);
        /([A-Z_]+)="(.*)"/;
        if($1)
	{
          $this->{SYSCONFIG}->{$1}= $2;
        }
      }
    }
    else
    {
        if( defined $dn && $dn ne '' )
        {
            $base = $dn;
        }
        my $mesg = $this->{LDAP}->search( base   => 'ou=sysconfig,'.$base,
                                  	  scope  => 'one',
            	              		  filter => '(objectClass=SchoolConfiguration)'
            	 );
        if( $mesg->code() || $mesg->count() < 1 )
        {
           $this->{ERROR}->{text}  = "ERROR Can not read the school configuration for dn=$dn\n";
           return 0;
        }
	undef $this->{SYSCONFIG} if defined $this->{SYSCONFIG};
        foreach my $entry ( $mesg->entries() )
        {
          $this->{SYSCONFIG}->{$entry->get_value('configurationKey')} = $entry->get_value('configurationValue');
        }
        $this->{SCHOOL_BASE} = $base;
    }
    if( !defined $this->{SCHOOL_BASE} )
    {
        $this->{SCHOOL_BASE} = $this->{LDAP_BASE};
    }
    $this->{SYSCONFIG}->{DHCP_BASE}       = 'ou=DHCP,'.$this->{LDAP_BASE}        if( !defined $this->{SYSCONFIG}->{DHCP_BASE} );
    $this->{SYSCONFIG}->{DNS_BASE}        = 'ou=DNS,'.$this->{LDAP_BASE}         if( !defined $this->{SYSCONFIG}->{DNS_BASE} );
    $this->{SYSCONFIG}->{COMPUTERS_BASE}  = 'ou=Computers,'.$this->{SCHOOL_BASE} if( !defined $this->{SYSCONFIG}->{COMPUTERS_BASE} );
    $this->{SYSCONFIG}->{USER_BASE}       = 'ou=people,'.$this->{SCHOOL_BASE}    if( !defined $this->{SYSCONFIG}->{USER_BASE} );
    $this->{SYSCONFIG}->{GROUP_BASE}      = 'ou=group,'.$this->{SCHOOL_BASE}     if( !defined $this->{SYSCONFIG}->{GROUP_BASE} );
    $this->{SYSCONFIG_BASE}               = 'ou=sysconfig,'.$this->{SCHOOL_BASE};
    return 1;
}
#-----------------------------------------------------------------------

=item B<is_unique(id,Type(user|group|mail|uid|cn,room)[,Base])>

Returns true if the identifier is unique in the LDAP database;

The Types can be:

   user    for unique uidnumber
   group   for unique gidnumber
   mail    for unique suseMailAcceptAddress 
   uid     for unique uid for a user
   cn      for unique cn for a group
   description for unique description for a group

EXAMPLE:

  my $is_unique = $oss->is_unique(1076,'user');

=cut

sub is_unique
{
    my $this = shift;
    my $id   = shift;
    my $type = shift;
    my $base = shift || $this->{LDAP_BASE};
    my $attribute = 'uidnumber';
    my $oc        = 'posixaccount';

    if( $type eq 'group')
    {
       $attribute = 'gidnumber';
       $oc        = 'posixgroup';
    }
    elsif( $type eq 'mail' )
    {
       $attribute = 'suseMailAcceptAddress';
       $oc        = 'suseMailRecipient';
    }
    elsif( $type eq 'uid' )
    {
       $attribute = 'uid';
    }
    elsif( $type eq 'cn' )
    {
       $attribute = 'cn';
       $oc        = 'posixgroup';
    }
    elsif( $type eq 'description' )
    {
       $attribute = 'description';
       $oc        = 'posixgroup';
    }
    elsif( $type eq 'room' )
    {
       $attribute = 'description';
       $oc        = 'schoolRoom';
    }

    my $mesg = $this->{LDAP}->search(
       			base   => $base,
			filter => "(&(objectClass=$oc)($attribute=$id))",
			attrs  => []
    );

    if( $mesg->count )
    {
      return 0;
    }

    return 1;
}
#-----------------------------------------------------------------------

=item B<reply>

Returns a list of dn hasches in  XML or text form depending on the value of $this->{XML}

EXAMPLE:

 print $oss->reply($users);

=cut

sub reply
{
    my $this = shift;
    my $result = shift;
    my $out    = '';

    if( $this->{XML} )
    {
      $out = reply_xml(hash_to_xml($result));
    }
    else 
    {
      $out = hash_to_text($result);
    }
    return $out;
}

#-----------------------------------------------------------------------

=item B<reply>

Returns a dn in  XML or text form depending on the value of $this->{XML}

EXAMPLE:

 print $oss->reply($users);

=cut

sub replydn
{
    my $this = shift;
    my $dn = shift;
    my $out    = '';

    if( $this->{XML} )
    {
      $out    = "<reply>\n";
      $out .= "  <dn>".$dn."</dn>\n";  
      $out .= "</reply>\n";
    }
    else
    {
      $out = $dn;
    }
    return $out;
}
#-----------------------------------------------------------------------

=item B<ldap_error(mesg)>

Evaluates the return value of an ldap operation and puts in the $this->{ERROR} hash.

EXAMPLE:

    my $mesg = $this->{LDAP}->search( base   => $this->{LDAP_BASE},
			      filter => "(&(objectClass=posixAccount)(uid=$uid))",
			      scope  => 'sub',
			      attrs  => [ 'uidNumber' ]
    );
    if( $mesg->code() ){
       $this->ldap_error($mesg);
       print $this->{ERROR}->{text};
       return undef;
    }
    return $mesg->entry(0)->get_value('uidNumber'); 


=cut

sub ldap_error($)
{
    my $this = shift;
    my $mesg = shift;

    $this->{ERROR}->{text}  = " LDAP-Server return code: ".$mesg->code ;
    $this->{ERROR}->{text} .= " Message: ".ldap_error_name($mesg->code);
    $this->{ERROR}->{text} .= "\n :".ldap_error_text($mesg->code);
    $this->{ERROR}->{text} .= "\n";

    $this->{ERROR}->{code}  = $mesg->code;
}
#-----------------------------------------------------------------------

#######################################################################################
# Utilities to manipulate the users						      #
#######################################################################################

sub create_cn($)
{
    my $this  = shift;
    my $USER  = shift;
    
    if( defined $USER->{givenname} && defined $USER->{sn} )
    {
	    if( $USER->{c} eq 'HU' )
	    {
	       $USER->{cn} = $USER->{addressbookcn} = $USER->{sn}.' '.$USER->{givenname};
	    }
	    else
	    {
	       $USER->{cn}            = $USER->{givenname}.' '.$USER->{sn};
	       $USER->{addressbookcn} = $USER->{sn}.', '.$USER->{givenname};
	    }
    }
    else
    {
       $USER->{cn} = $USER->{sn};
    }
    $USER->{displayname} = $USER->{cn};
}

sub create_uid($)
{
    my $this  = shift;
    my $USER  = shift;
    my $uid = "";

    my $gn      = string_to_ascii($USER->{givenname});
    my $sn      = string_to_ascii($USER->{sn});
    my %uidhash = ( N=>4, G=>4 );
    my @order   = ( 'N','G' );

    $USER->{prefix}  = lc($this->{SYSCONFIG}->{SCHOOL_LOGIN_PREFIX}) || '';

    if( $this->{SYSCONFIG}->{SCHOOL_LOGIN_SCHEME} =~ /(\D)(\d+)(\D)(\d+)(\D)(\d+)/ )
    {
        %uidhash = ( $1 => $2, $3 => $4, $5 => $6 );
	@order   = ( $1, $3, $5 );
    }
    elsif( $this->{SYSCONFIG}->{SCHOOL_LOGIN_SCHEME} =~ /(\D)(\d+)(\D)(\d+)/ )
    {
        %uidhash = ( $1 => $2, $3 => $4 );
	@order   = ( $1, $3 );
    }

    foreach my $i ( @order )
    {
        if( $i eq 'N' )
        {
            $uid .= substr( $sn, 0 , $uidhash{$i} );
        }
        elsif( $i eq 'G' )
        {
            $uid .= substr( $gn, 0 , $uidhash{$i} );
        }
        elsif( $i eq 'Y' )
        {
            if( $uidhash{$i} == 2 )
	    {
	        $USER->{birthday} =~ /\d\d(\d\d)-\d\d-\d\d/;
    	        $uid .= $1;
	    }
	    else
	    {
	        $USER->{birthday} =~ /(\d\d\d\d)-\d\d-\d\d/;
    	        $uid .= $1;
	    }
        }
    }
    $uid = lc($uid);
    my $newuid = $USER->{prefix}.$uid;
    my $c      = 0;
    while( ! $this->is_unique($newuid,'uid') )
    {
       $c++;
       $newuid = $USER->{prefix}.$uid.$c;
    }
    $USER->{uid} = $uid;
    if( $c )
    {
       $USER->{uid} = $uid.$c;
    }
}
#-----------------------------------------------------------------------

=item B<add_user_to_group(userDN,groupDN)>

Add an user to a group.

EXAMPLE:

 $oss->add_user_to_group('uid=micmou,ou=people,dc=schule,dc=de','cn=5A,ougroup,dc=schule,dc=de');

=cut

sub add_user_to_group($$)
{
    my $this = shift;
    my $udn  = shift;
    my $gdn  = shift;

    if( !defined $udn || !defined $gdn )
    {
    	return 0;
    }
    my $mesg = undef;

    my $gidnumber   = $this->get_attribute($gdn,'gidnumber');
    my $uid         = get_name_of_dn($udn);
    my $cn          = get_name_of_dn($gdn);

    if( $this->is_class($gdn) && $this->is_student($udn) && ( $this->{SYSCONFIG}->{SCHOOL_TEACHER_OBSERV_HOME} eq 'yes' )  )
    {
    	system("ln -s ".$this->{SYSCONFIG}->{SCHOOL_HOME_BASE}."/students/$uid  ".$this->{SYSCONFIG}->{SCHOOL_HOME_BASE}."/classes/$cn/$uid");
    }
    $mesg = $this->{LDAP}->modify($gdn, add=> { member    => $udn }); 
    if( $mesg->code() ){
       $this->ldap_error($mesg);
       return 0;
    }
    $this->{LDAP}->modify($gdn, add=> { memberUID => $uid }); 
    if( $mesg->code() ){
       $this->ldap_error($mesg);
       return 0;
    }
    $this->{LDAP}->modify($udn, add=> { OXGroupID => $gidnumber });
    if( $mesg->code() ){
       $this->ldap_error($mesg);
       return 0;
    }
    # Not needed if the memberOf overlay is loaded
    # $this->{LDAP}->modify($udn, add=> { memberOf  => $gdn });
    # Zarafa do not need IMAP
    # TODO What happends with shared mailboxes???
    return 1 if( defined $this->{SYSCONFIG}->{SCHOOL_USE_ZARAFA} && $this->{SYSCONFIG}->{SCHOOL_USE_ZARAFA} eq 'yes' );

    if( $this->is_teacher($udn) && $this->is_class($gdn) )
    {
        $this->{IMAP}->setacl(get_name_of_dn($gdn),$uid,"lrswipte");
    }
    return 1;
}
#-----------------------------------------------------------------------

=item B<disable_user(dn)>

Disable an user to login.

EXAMPLE:

  disable_user('uid=micmou,ou=people,dc=schule,dc=de');

=cut

sub disable_user($)
{
    my $this = shift;
    my $dn   = shift;

    $this->{LDAP}->modify( $dn , replace => { logindisabled  => 'yes'} );
    $this->{LDAP}->modify( $dn , replace => { sambaAcctFlags => '[UD         ]'} );
    $this->{LDAP}->modify( $dn , delete  => 'shadowExpire' );
    $this->{LDAP}->modify( $dn , add     => { shadowExpire => 1 });
}
#-----------------------------------------------------------------------

=item B<enable_user(dn)>

Enable an user to login.

EXAMPLE:

 enable_user('uid=micmou,ou=people,dc=schule,dc=de');

=cut

sub enable_user($)
{
    my $this = shift;
    my $dn = shift;

    $this->{LDAP}->modify( $dn , replace => { sambaAcctFlags => '[U          ]'} );
    $this->{LDAP}->modify( $dn , replace => { logindisabled  => 'no'} );
    $this->{LDAP}->modify( $dn , delete  => 'shadowExpire' );
}
#-----------------------------------------------------------------------

=item B<archiv_user(dn)>

Archiv an user.

EXAMPLE:

 archiv_user('uid=micmou,ou=people,dc=schule,dc=de');

=cut

sub archiv_user($)
{
    my $this = shift;
    my $dn   = shift;

    #TODO Is not ready

}
#-----------------------------------------------------------------------

=item B<delete_user_from_group(userDN,groupDN)>

Delets an user from a group. Delets the acls of the on the shared mailbox too.

EXAMPLE:

 $oss->delete_user_from_group('uid=micmou,ou=people,dc=schule,dc=de','cn=5A,ougroup,dc=schule,dc=de');

=cut

sub delete_user_from_group($$)
{
    my $this = shift;
    my $udn  = shift;
    my $gdn  = shift;

    my $gidnumber   = $this->get_attribute($gdn,'gidnumber');
    my $uid         = get_name_of_dn($udn);
    my $cn          = get_name_of_dn($gdn);

    if( $this->is_class($gdn) && $this->is_student($udn) && ( $this->{SYSCONFIG}->{SCHOOL_TEACHER_OBSERV_HOME} eq 'yes' )  )
    {
    	system("rm  ".$this->{SYSCONFIG}->{SCHOOL_HOME_BASE}."/classes/$cn/$uid");
    }
    $this->{LDAP}->modify($gdn, delete=> { member    => $udn }); 
    $this->{LDAP}->modify($gdn, delete=> { memberUID => $uid }); 
    $this->{LDAP}->modify($udn, delete=> { OXGroupID => $gidnumber });
    # Not needed if the memberOf overlay is loaded
    # $this->{LDAP}->modify($udn, delete=> { memberOf  => $gdn });
    # TODO What happends with shared mailboxes???
    $this->{IMAP}->deleteacl(get_name_of_dn($gdn),$uid) if( $this->{withIMAP} );
}
#-----------------------------------------------------------------------

=item B<get_classes_of_user(dn)>

Get the classes of the user.

EXAMPLE:

  my  

=cut

sub get_classes_of_user($)
{
    my $this   = shift;
    my $dn     = shift;
    my @groups = ();

    my $base   = $this->get_school_base($dn);
    my $mesg   = $this->{LDAP}->search( base   => 'ou=group,'.$base,
			                filter => "(&(grouptype=class)(member=$dn))",
			                scope  => 'one',
			                attrs  => [ 'dn' ]
    );
    if( $mesg->code() )
    {
       return undef;
    }
    foreach my $entry ( $mesg->entries() )
    {
      push @groups, $entry->dn();
    }
    return \@groups;
}
#-----------------------------------------------------------------------


=item B<get_groups_of_user(dn,all)>

Get the groups the user. If all is true all groups will be searched not
only the schoolGroups.

=cut

sub get_groups_of_user
{
    my $this   = shift;
    my $dn     = shift;
    my $all    = shift || 0;
    my @groups = ();
    my $primarygroup = $this->get_primary_group_of_user($dn);
    my $filter =  "(&(member=$dn)(objectclass=schoolGroup))";

    if( $all )
    {
      $filter =  "(member=$dn)";
    }

    my $mesg = $this->{LDAP}->search( base   => $this->{LDAP_BASE},
			              filter => $filter,
			              scope  => 'sub',
			              attrs  => [ 'dn' ]
    );
    if( $mesg->code() )
    {
       return undef;
    }
    foreach my $entry ( $mesg->entries() )
    {
      if( $all || ($entry->dn() ne $primarygroup) )
      {
        push @groups, $entry->dn();
      }
    }
    return \@groups;
}
#-----------------------------------------------------------------------

=item B<get_primary_group_of_user(dn)>

Get the primary group of an user.

=cut

sub get_primary_group_of_user($)
{
    my $this    = shift;
    my $dn      = shift;

    my $gidnumber = $this->get_attribute($dn,'gidnumber');
    my $base      = $this->get_school_base($dn);
    my $mesg = $this->{LDAP}->search( base   => 'ou=group,'.$base,
			              filter => "gidnumber=$gidnumber",
			              scope  => 'one',
			              attrs  => [ 'dn' ]
    );
    if( $mesg->code() ||  !$mesg->count )
    {
       return undef;
    }
    return $mesg->entry(0)->dn();
}
#-----------------------------------------------------------------------

=item B<get_fquota(dn)>

Returns the file system quota of an user.

EXAMPLE:

  my ( $quotalimit, $quotavalue ) = get_fquota('uid=varkpete,ou=people,dc=extis,dc=de');

=cut

sub get_fquota($)
{
    my $this = shift;
    my $dn   = shift;
    my $uid  = $this->get_attribute($dn,'uidnumber');
    my $dev  = Quota::getqcarg("/home");
    #my ($q_used,$q_val,$block_hard, $block_timelimit,$inode_curr, $inode_soft, $inode_hard, $inode_timelimit) = Quota::query($dev ,$uid,0);
    my $quota= `/usr/bin/quota -l -w -u $uid | grep $dev`; chomp $quota;
    $quota =~ s/^.*$dev/$dev/g;
    my ($q_dev,$q_used,$q_val,$q_rest) = split /\s+/, $quota;
    if( defined $q_val )
    {
      $q_val = $q_val / 1024;
    }
    else
    {
      $q_val = 0;
    }
    if( defined $q_used && $q_val )
    {
      $q_used = $q_used / 1024;
    }
    else
    {
      $q_used = 0;
    }
    return ($q_val,$q_used);
}
#-----------------------------------------------------------------------

=item B<get_mbox_acl(mailbox)>

Returns the mailsystem acl of a mailbox

EXAMPLE:

  my $acls = $oss->get_mbox_acl('TEACHERS');

  foreach my $owner ( keys %{$acls} )
  {
  	print "Acls on TEACHERS for $owner: ".$acls->{$owner}."\n";
  }

But the mailbox can be an DN of an object owning a mailbox too:

  my $acls = $oss->get_mbox_acl('TEACHERS');

=cut

sub get_mbox_acl($)
{
    my $this = shift;
    my $mbox = shift;

    # Zarafa do not need IMAP
    # TODO What happends with shared mailboxes???
    return if( defined $this->{SYSCONFIG}->{SCHOOL_USE_ZARAFA} && $this->{SYSCONFIG}->{SCHOOL_USE_ZARAFA} eq 'yes' );

    my %acls = ();

    if( $mbox =~ /^uid=.*/ )
    {
        $mbox = 'user/'.get_name_of_dn($mbox);
    }
    elsif( $mbox =~ /^cn=.*/ )
    {
        $mbox = get_name_of_dn($mbox);
    }

    my $anf = sub
    {
        my $self = shift;
        my $resp = shift;

	foreach ($resp->identifiers)
	{
	    $acls{$_} = $resp->identifier($_);
	}
        
    };

    $this->{IMAP}->set_untagged_callback('acl', $anf);

    my $resp = $this->{IMAP}->getacl($mbox);
   
    return (\%acls);
}
#-----------------------------------------------------------------------

=item B<get_quota(dn)>

Returns the mailsystem quota of an user

EXAMPLE:

  my ( $quotalimit, $quotavalue ) = $oss->get_quota('uid=varkpete,ou=people,dc=extis,dc=de');

=cut

sub get_quota($)
{
    my $this = shift;
    my $dn = shift;
    my $uid = get_name_of_dn($dn);

    my ($q_val,$q_used) = (0,0);
    if( defined $this->{SYSCONFIG}->{SCHOOL_USE_ZARAFA} && $this->{SYSCONFIG}->{SCHOOL_USE_ZARAFA} eq 'yes' )
    {
        my $tmp = `ssh mailserver /usr/sbin/oss_get_zquota $uid`;
        ($q_used,$q_val) = split / /,$tmp;
    }
    else
    {
	    return ($q_val,$q_used) if ( ! defined $this->{IMAP} );

	    my $uid = get_name_of_dn($dn);

	    my $anf = sub
	    {
		my $self = shift;
		my $resp = shift;
		
		$q_val  = $resp->limit("STORAGE") || 0;
		$q_used = $resp->usage("STORAGE") || 0;
		$q_val  = $q_val/1024;
		$q_used = $q_used/1024;
	    };

	    $this->{IMAP}->set_untagged_callback('quota', $anf);

	    my $resp = $this->{IMAP}->getquotaroot("user/$uid");
    }
   
    return ($q_val,$q_used);
}
#-----------------------------------------------------------------------

=item B<get_primary_group(role,[SchoolBase])>

Returns the dn of the primary group of a role. 

EXAMPLE:

  my $dn = $oss->get_primary_group('teachers');

=cut

sub get_primary_group
{
    my $this = shift;
    my $role = shift;
    my $mesg = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{GROUP_BASE},
                                      scope  => 'one',
          		              filter => "(role=$role)",
				      attrs  => ['dn']
          		            );
    
    if( $mesg->code() || $mesg->count() != 1 )
    {
      return undef;
    }
    return $mesg->entry(0)->dn();
   
}
#-----------------------------------------------------------------------

=item B<get_template_user(role,[SchoolBase])>

Returns the dn of the template user a role. 

EXAMPLE:

  my $dn = $oss->get_template_user('teachers');

=cut

sub get_template_user
{
    my $this = shift;
    my $role = shift;
   
    my $mesg = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{USER_BASE},
                                      scope  => 'one',
                                      filter => "(&(role=templates)(uid=t$role))",
                                );
 
    if( $mesg->code() || $mesg->count() != 1 )
    {
      $this->{ERROR}->{code} = "NO-SUCH-TEMPLATE-USER";
      return undef;
    }
    return $mesg->entry(0)->dn();
   
}
#-----------------------------------------------------------------------

=item B<search_users(name [,\@groups1,\@groups2, \@groups3])>

Returns the datas of users which are member in the listed groups.
The function may have up to 3 list of groups. The groups in a list
are connected with logical OR and the list by logical AND.

E.m.: we are searching the users which 
	* uid givenName or sn matches 'name'
	AND
	* are member in one of the group @groups1
	AND
	* are member in one of the group @groups2
	AND
	* are member in one of the group @groups3


EXAMPLE:

  @groups1 = ('cn=students,ou=group,dc=extis,dc=de');
  @groups2 = ('cn=10A,ou=group,dc=extis,dc=de','cn=10B,ou=group,dc=extis,dc=de');
  my $user = $oss->search_users('*',\@groups1,\@groups1);

=cut

sub search_users
{
    my $this         = shift;
    my $name         = shift;
    my $group1       = shift || ();
    my $group2       = shift || ();
    my $group3       = shift || ();
    my ( $n1 , $n2 , $n3 ) = 0;
    my ( $f1 , $f2 , $f3 ) = '';

    my $filter = "(&(objectclass=schoolAccount)(|(name=$name)(uid=$name))";

    foreach my $f (@{$group1})
    {
	$f1 .= '(memberOf='.$f.')';
	$n1++;
    }
    if( $n1 > 1 )
    {
	$f1 = '(|'.$f1.')';
    }
    if( $n1 )
    {
        $filter .= $f1;
    }
    foreach my $f (@{$group2})
    {
	$f2 .= '(memberOf='.$f.')';
	$n2++;
    }
    if( $n2 > 1 )
    {
	$f2 = '(|'.$f2.')';
    }
    if( $n2 )
    {
        $filter .= $f2;
    }
    foreach my $f (@{$group3})
    {
	$f3 .= '(memberOf='.$f.')';
	$n3++;
    }
    if( $n3 > 1 )
    {
	$f3 = '(|'.$f3.')';
    }
    if( $n3 )
    {
        $filter .= $f3;
    }
    $filter .= ')';
    my $mesg = $this->{LDAP}->search(
    			  base   => $this->{SYSCONFIG}->{USER_BASE},
                          scope  => 'one',
                          filter => $filter,
                          attrs  => ['uid','cn','description']
                        );
    if( ! $mesg )
    {
        $this->{ERROR}->{text} = "ERROR Could not search the user";
	return undef;
    }
    return $mesg->as_struct;

}

#-----------------------------------------------------------------------

=item B<get_user(dn,[list of attributes])>

Returns the datas of an user.

EXAMPLE:

  my $user = $oss->get_user('uid=varkpete,ou=people,dc=extis,dc=de');
  print $user->{cn};
  my $user = $oss->get_user('uid=varkpete,ou=people,dc=extis,dc=de',[ 'birthday', 'preferreddrink'] );
  print $user->{birthday};

=cut

sub get_user
{
    my $this         = shift;
    my $dn           = shift;
    my $attrs        = shift || $this->{DEFAULT_USER_ATTRIBUTES};

    my $admin        = 0;
    my $mesg = $this->{LDAP}->search( base   => $dn,
                          scope  => 'base',
                          filter => '(objectclass=SchoolAccount)',
                          attrs  => $attrs
                        );
    if( ! $mesg )
    {
        $this->{ERROR}->{text} = "ERROR Could not search the user";
	return undef;
    }
    my $result = $mesg->as_struct;
    #Getting the mail quota
    if( contains('quota',$attrs))
    {
      my($q_val,$q_used) = $this->get_quota($dn);
      push @{$result->{$dn}->{quota}},"$q_val";
      push @{$result->{$dn}->{quotaused}},"$q_used";
    }

    #Getting the filesystem quota
    if( contains('fquota',$attrs))
    {
      my($q_val,$q_used) = $this->get_fquota($dn);
      push @{$result->{$dn}->{fquota}},"$q_val";
      push @{$result->{$dn}->{fquotaused}},"$q_used";
    }  

    #Getting the groups
    if( contains('group',$attrs))
    {
      my $primary_group = $this->get_primary_group_of_user($dn);
      push @{$result->{$dn}->{primarygroup}},$primary_group;
      foreach my $grp (@{$this->get_groups_of_user($dn)})
      {
        if( $grp =~ /^cn=sysadmins,/i || $grp =~ /^cn=.*-sysadmins,/i )
        {
          $admin = 1;
        }
	else
	{
        	push @{$result->{$dn}->{group}},$grp if ($grp ne $primary_group) ;
	}
      }
      if( $admin || $primary_group =~ /^cn=sysadmins,/i  || $primary_group =~ /^cn=.*-sysadmins,/i )
      {
        push @{$result->{$dn}->{admin}},1;
      }
      else
      {
        push @{$result->{$dn}->{admin}},0;
      }
    }   
    return $result->{$dn};
}

#-----------------------------------------------------------------------

=item B<get_users_of_group(dn,hash)>

Returns the member of a group. If C<hash> is true, the result is a hash else
it is an array of the members dns.

EXAMPLE:

hash:

  my $users = $oss->get_users_of_group('cn=10A,ou=group,dc=extis,dc=de',1);
  foreach $user ( keys %{$users} ) {
    print $users->{$user}->{cn}." :: ".$users->{$user}->{cn}." :: ".$users->{$user}->{description}."\n";
  }

array:

  my $users = $oss->get_users_of_group('cn=10A,ou=group,dc=extis,dc=de',0);
  foreach $user ( @{$users} ) {
     $oss->disable_user($user}; 
  }

=cut

sub get_users_of_group
{
    my $this        = shift;
    my $dn          = shift;
    my $hash        = shift || 0;

    my $values      = $this->get_attributes($dn,['member']);
    my @tmp         = @{$values->{member}};
    my $result      = {};
    my @members     = ();
    foreach my $member ( @tmp )
    {
	my $uid = get_name_of_dn($member);
	next if( $uid eq 'admin' || $uid eq 'root' );
	push @members,$member;
    }
    if( $hash )
    {
      foreach my $member ( @members )
      {
        push @{$result->{$member}->{uid}}, $this->get_attribute($member,'uid'); 
        push @{$result->{$member}->{cn}}, $this->get_attribute($member,'cn'); 
        push @{$result->{$member}->{description}}, $this->get_attribute($member,'description'); 
      }
      return $result;
    }
    return \@members;
}

#-----------------------------------------------------------------------

=item B<get_students_of_group(dn)>

Returns the students of a group. If C<hash> is true, the result is a hash else
it is an array of the members dns.

EXAMPLE:

hash:

  my $students = $oss->get_students_of_group('cn=10A,ou=group,dc=extis,dc=de',1);
  foreach $user ( keys %{$students} ) {
    print $students->{$user}->{uid}." :: ".$students->{$user}->{cn}." :: ".$students->{$user}->{description}."\n";
  }

array:

  my $students = $oss->get_students_of_group('cn=10A,ou=group,dc=extis,dc=de',0);
  foreach $user ( @{$students} ) {
     $oss->disable_user($user}; 
  }

=cut

sub get_students_of_group($)
{
    my $this        = shift;
    my $dn          = shift;
    my $hash        = shift || 0;
    my @members     = ();
    my $result      = {};
	my $t1     = $this->get_attributes($dn,['member']);
        my @t2     = @{$t1->{member}};

    foreach my $member ( @t2 )
    {
        if( $this->is_student($member) )
        {
            push @members, $member;
            if( $hash )
            {
                push @{$result->{$member}->{uid}},         $this->get_attribute($member,'uid'); 
                push @{$result->{$member}->{cn}},          $this->get_attribute($member,'cn'); 
                push @{$result->{$member}->{description}}, $this->get_attribute($member,'description'); 
            }
        }
    }
    if( $hash )
    {
      return $result;
    }
    return \@members;
}
#-----------------------------------------------------------------------

=item B<get_teachers_of_group(dn)>

Returns the teachers of a group. If C<hash> is true, the result is a hash else
it is an array of the members dns.

EXAMPLE:

hash:

  my $teachers = $oss->get_teachers_of_group('cn=10A,ou=group,dc=extis,dc=de',1);
  foreach $user ( keys %{$teachers} ) {
    print $teachers->{$user}->{cn}." :: ".$teachers->{$user}->{cn}." :: ".$teachers->{$user}->{description}."\n";
  }

array:

  my $teachers = $oss->get_teachers_of_group('cn=10A,ou=group,dc=extis,dc=de',0);
  foreach @user ( @{$teachers} ) {
     $oss->disable_user($user}; 
  }

=cut

sub get_teachers_of_group($)
{
    my $this        = shift;
    my $dn          = shift;
    my $hash        = shift || 0;
    my $values      = $this->get_attributes($dn,['member']);
    my @members     = @{$values->{member}};
    my $result      = {};

    if( $hash )
    {
      foreach my $member ( @members )
      {
        if( $this->is_teacher($member) )
	{
          push @{$result->{$member}->{uid}}, $this->get_attribute($member,'uid'); 
          push @{$result->{$member}->{cn}},  $this->get_attribute($member,'cn'); 
          push @{$result->{$member}->{description}}, $this->get_attribute($member,'description'); 
        }
      }
      return $result;
    }

    return \@members;
}

#-----------------------------------------------------------------------

=item B<is_admin(dn)>

Returns 1 if the dn is a dn of an user with sysadmin rights.

=cut

sub is_admin($)
{
    my $this   = shift;
    my $dn     = shift;

    my $result = $this->{LDAP}->search(
    			base	=> $dn,
			scope	=> 'base',
			filter	=> 'role=*sysadmins*',
			attrs   => ['dn']
    );
    if( defined $result && $result->count ==1 )
    {
      return 1;
    }
    return 0;
}
#-----------------------------------------------------------------------

=item B<is_user(dn)>

Returns 1 if the dn is a dn of an user.

=cut

sub is_user($)
{
    my $this   = shift;
    my $dn     = shift;

    my $result = $this->{LDAP}->search(
    			base	=> $dn,
			scope	=> 'base',
			filter	=> 'objectclass=posixAccount',
			attrs   => ['dn']
    );
    if( defined $result && $result->count ==1 )
    {
      return 1;
    }
    return 0;
}
#-----------------------------------------------------------------------

=item B<is_student(dn)>

Returns 1 if the dn is a dn of a student.

=cut

sub is_student($)
{
    my $this   = shift;
    my $dn     = shift;

    my $result = $this->{LDAP}->search(
    			base	=> $dn,
			scope	=> 'base',
			filter	=> 'role=students*',
			attrs   => ['dn']
    );
    if( defined $result && $result->count ==1 )
    {
      return 1;
    }
    return 0;
}
#-----------------------------------------------------------------------

=item B<is_teacher(dn)>

Returns 1 if the dn is a dn of a teacher.

=cut

sub is_teacher($)
{
    my $this   = shift;
    my $dn     = shift;

    my $result = $this->{LDAP}->search(
    			base	=> $dn,
			scope	=> 'base',
			filter	=> 'role=teachers*',
			attrs   => ['dn']
    );
    if( defined $result && $result->count ==1 )
    {
      return 1;
    }
    return 0;
}
#-----------------------------------------------------------------------

=item B<is_template(dn)>

Returns 1 if the dn is a dn of a template.

=cut

sub is_template($)
{
    my $this   = shift;
    my $dn     = shift;

    my $result = $this->{LDAP}->search(
    			base	=> $dn,
			scope	=> 'base',
			filter	=> 'role=templates*',
			attrs   => ['dn']
    );
    if( defined $result && $result->count ==1 )
    {
      return 1;
    }
    return 0;
}
#-----------------------------------------------------------------------

=item B<is_workstation(dn)>

Returns 1 if the dn is a dn of a workstation user.

=cut

sub is_workstation($)
{
    my $this   = shift;
    my $dn     = shift;

    my $result = $this->{LDAP}->search(
    			base	=> $dn,
			scope	=> 'base',
			filter	=> 'role=workstations*',
			attrs   => ['dn']
    );
    if( defined $result && $result->count ==1 )
    {
      return 1;
    }
    return 0;
}
#-----------------------------------------------------------------------

=item B<is_guest(dn)>

Returns 1 if the dn is a dn of a guest user.

=cut

sub is_guest($)
{
    my $this   = shift;
    my $dn     = shift;

    my $gid    = $this->get_attribute($dn,"gidnumber");
    if( !defined $gid )
    {
        return 0;
    }
    my $result = $this->{LDAP}->search(
    			base	=> $this->{SYSCONFIG}->{GROUP_BASE},
			scope	=> 'one',
			filter	=> "(&(grouptype=guest)(gidnumber=$gid))",
			attrs   => ['dn']
    );
    if( defined $result && $result->count ==1 )
    {
      return 1;
    }
    return 0;
}
#-----------------------------------------------------------------------

=item B<login(dn,password,remote-IP,session)>

Check the login parameter of the user, and returns his attributes.

C<dn> is the dn of the user how want to login.

C<password> is the user's password.

C<remote-IP> ist the IP-Address of the machine the login request comming from.

C<session> shows if a session must be created or not (1|0).

=cut

sub login
{
    my $this = shift;
    my $dn       = shift;
    my $password = shift;
    my $remote   = shift;
    my $session  = shift;
    my $uid      = '';
    my $lang     = 'EN';
    my $mesg;
    # TODO THESE VARIABLES MUST BE CONFIGURABLE
    my $timeout = 3600;
    # 1 = unix / 2 = ssl / 3 = plain
    my $connection_mode = 3;


    #Now we search the account
    $mesg = $this->{LDAP}->search( base   => $dn,
    			   	   scope  => 'base',
			           attr   => [],
			           filter => "(!(loginDisabled=yes))"
			         );
    if( $mesg->code() || $mesg->count() != 1 )
    {
      $this->{ERROR}->{text} = "Login denied\n";
      return undef;
    }
    $mesg = $this->{LDAP}->bind( $dn, password =>  $password);
    if( $mesg->code != 0)
    {
      $this->{ERROR}->{text} = "Login failed\n";
      return undef;
    }
   
    #Now we get all the data of the user
    $mesg = $this->{LDAP}->search( base   => $dn,
    			           scope  => 'base',
			           filter => 'objectclass=*',
			         );
    my $result = $mesg->as_struct;
    my %data   = ();
    foreach my $attr ( keys %{$result->{$dn}} )
    {
      $data{$attr} = join "::",@{$result->{$dn}->{$attr}};
    }
    if( defined $data{preferredlanguage} ) {
	$lang = $data{preferredlanguage};
    }
    $uid = $data{uid};

    #-- calculate if the account is expired
    my $days_since_1970 = int(timelocal(localtime()) / 3600 / 24);

    if( defined $data{shadowExpire} && $data{shadowExpire} ne "" && $data{shadowExpire} < $days_since_1970)
    {
      $this->{ERROR}->{text} = "Login expired";
      return undef;
    }

    # Create a new session if neccessary
    if( $session )
    {
      my $dref = \%data;
      my $rand = rand((time)*$$);
      my $ID = md5_hex($rand.$dref);

      my $authdata = encode_base64($uid."\1".$password."\1".$lang."\1".$remote);
      $authdata =~ s/\n//g;

      my $SOCK = getSocket($connection_mode);
      my $timestamp = timelocal(localtime());
      my $frozen = freeze($dref);
      $frozen = unpack('H*',$frozen);

      print $SOCK "add: $timestamp $timeout $ID $authdata $frozen\0";
      $SOCK->flush();
      push @{$result->{$dn}->{'SESSIONID'}}, $ID;
   }

   #Now we search  for the users group
   push @{$result->{$dn}->{'group'}},@{$this->get_groups_of_user($dn)};
   push @{$result->{$dn}->{'primarygroup'}},$this->get_primary_group_of_user($dn);
   return $result; 
}
#-----------------------------------------------------------------------

=item B<set_password(dn, password, mustchange, sso, hash)>

Set the user password (samba and LDAP).

 
EXAMPLE:

  set_password('uid=varkpete,ou=people,dc=extis,dc=de','12345678',1,0,'smd5');

=cut

sub set_password($$$$$)
{
    my $this = shift;
    my $dn         = shift;
    my $password   = shift;
    my $mustchange = shift;
    my $sso        = shift;
    my $pwmech     = shift;
    my $pwlength   = $this->get_school_config('SCHOOL_MINIMAL_PASSWORD_LENGTH') || '6';    
    if( length($password) < $pwlength ){
	$this->{ERROR}->{text} = "The user password is at least $pwlength characters long.<br>";
	return 0;
    }
    my $uid = get_name_of_dn($dn);
    my $crypt_password = hash_password($pwmech,$password);
    my $time            = timelocal(localtime());
    my $days_since_1970 = int($time / 3600 / 24);
    my ( $lm, $nt ) = ntlmgen $password;
    my @mod_op;
    my @mod_op_1;
    my @mod_op_2;
    my $entry     = $this->get_entry( $dn, 1);
    push @mod_op, "replace", [ "sambaLMPassword", "$lm" ];
    push @mod_op, "replace", [ "sambaNTPassword", "$nt" ];
    push @mod_op, "replace", [ "userpassword", "$crypt_password" ];
    if( $mustchange )
    {
        push @mod_op, "replace", [ "shadowlastchange", "0" ];
        push @mod_op, "replace", [ "sambaPwdMustChange", "0" ];
        push @mod_op, "replace", [ "sambapwdlastset", "0" ];
    }
    else
    {
        push @mod_op,   "replace", [ "shadowlastchange", "$days_since_1970" ];
        push @mod_op_1, "replace", [ "sambaPwdMustChange" , -1];
        push @mod_op,   "replace", [ "sambapwdlastset", $time ];
    }
    if( $sso )
    {
    	my $authdata =  encode_base64($uid."\1".$password);
	if( $entry->exists('authData') )
	{
    		push @mod_op, "replace", [ "authData", "$authdata" ];
	}
	else
	{
    		push @mod_op, "add", [ "authData", "$authdata" ];
	}
    }
    else
    {
	if( $entry->exists('authData') )
	{
    		push @mod_op_2, "delete", ["authData" , []];
	}
    }
    
    my $mesg = $this->{LDAP}->modify( $dn, changes => \@mod_op );
    if( $mesg->code() ){
       $this->ldap_error($mesg);
       return 0;
    }
    if( @mod_op_1 )
    {
        $mesg = $this->{LDAP}->modify( $dn, changes => \@mod_op_1 );
	if( $mesg->code() ){
	   $this->ldap_error($mesg);
	   return 0;
	}
    }
    if( @mod_op_2 )
    {
	$mesg = $this->{LDAP}->modify( $dn, changes => \@mod_op_2 );
	if( $mesg->code() ){
	   $this->ldap_error($mesg);
	   return 0;
	}
    }
    my $TMPFILE = write_tmp_file("$dn\nuserpassword $password");
    system("/usr/share/oss/plugins/plugin_handler.sh modify_user $TMPFILE &> /dev/null");
    return 1;

}
#-----------------------------------------------------------------------

=item B<set_fquota(dn,MB)>

Sets the file system quota of an user.

EXAMPLE:

  $oss->set_fquota('uid=varkpete,ou=people,dc=extis,dc=de',200);

=cut

sub set_fquota
{
    my $this    = shift;
    my $dn      = shift;
    my $fquota  = shift;
    my $fsystem = shift || '/home';
    
    my $uid     = $this->get_attribute($dn,'uidnumber');
    my $dev     = Quota::getqcarg($fsystem);
    $fquota     *= 1024;
    system("/usr/sbin/setquota -u $uid $fquota $fquota 0 0 /home");
#    Quota::setqlim($dev, $uid, $fquota,$fquota, 0, 0, 0, 0);

}
#-----------------------------------------------------------------------

=item B<set_quota(dn,MB)>

Sets the mail system quota of an user.

EXAMPLE:

  $oss->set_quota('uid=varkpete,ou=people,dc=extis,dc=de',200);

=cut

sub set_quota
{
    my $this    = shift;
    my $dn      = shift;
    my $quota   = shift;
    my $uid     = get_name_of_dn($dn);

    if( defined $this->{SYSCONFIG}->{SCHOOL_USE_ZARAFA} && $this->{SYSCONFIG}->{SCHOOL_USE_ZARAFA} eq 'yes' )
    {

        my $mesg = $this->{LDAP}->modify( $dn, replace => { zarafaQuotaWarn => int($quota*0.8),
                                                            zarafaQuotaSoft => int($quota),
                                                            zarafaQuotaHard => int($quota*1.1)} );
        print "Setquota ".$mesg->code().":".$quota*0.8."\n";
        $this->ldap_error($mesg);
        print $this->{ERROR}->{code}."\n";
        print $this->{ERROR}->{text}."\n";
        system("ssh mailserver /usr/bin/zarafa-admin --force-resync $uid");
    }
    else
    {
	    my @qarray = ();
	    if( $quota )
	    {
	      @qarray = ("STORAGE", $quota * 1024 );
	    }
	    $this->{IMAP}->setquota("user/$uid", @qarray);
     }
}

#-----------------------------------------------------------------------

=item B<set_mbox_acl(mbox,owner,acl)>

Sets the mail system acl for a mbox.

EXAMPLE:

  $oss->set_mbox_acl('TEACHERS','group:SEKRETATIAT','lrs');

But both mbox and owner can be a dn of an object too:

  $oss->set_mbox_acl('TEACHERS','uid=varkpete,ou=people,dc=extis,dc=de','lrs');

  $oss->set_mbox_acl('cn=SEKRETATIAT,ou=group,dc=extis,dc=de','cn=TEACHERS,ou=group,dc=extis,dc=de','lrs');

=cut

sub set_mbox_acl
{
    my $this    = shift;
    my $mbox    = shift;
    my $owner   = shift;
    my $acl     = shift;

    if( $mbox =~ /^uid=.*/ )
    {
        $mbox = 'user/'.get_name_of_dn($mbox);
    }
    elsif( $mbox =~ /^cn=.*/ )
    {
        $mbox = get_name_of_dn($mbox);
    }

    if( $owner =~ /^uid=.*/ )
    {
        $owner = get_name_of_dn($owner);
    }
    elsif( $owner =~ /^cn=.*/ )
    {
        $owner = 'group:'.get_name_of_dn($owner);
    }
    $this->{IMAP}->setacl($mbox,$owner,$acl);
}
#-----------------------------------------------------------------------

=item b<update_cn(dn)>

Updates the user attributes CN and addressBookCN. This is neccessary if 
sn or givenName was changed.

EXAMPLE:

  $oss->update_cn('uid=varkpete,ou=people,dc=extis,dc=de');

=cut

sub update_cn($)
{
    my $this = shift;
    my $dn = shift;

    my $sn   = $this->get_attribute($dn,'sn');
    my $gn   = $this->get_attribute($dn,'givenName');
    my $lang = $this->get_attribute($dn,'preferredLanguage') || 'EN';

    if( $gn )
    {
    	if( $lang eq 'HU' )
	{
	    $this->{LDAP}->modify( $dn, replace => { cn => "$sn $gn", addressBookCN => "$sn $gn" });
	}
	else
	{
	    $this->{LDAP}->modify( $dn, replace => { cn => "$gn $sn", addressBookCN => "$sn, $gn" });
	}
    }
    else
    {
    	$this->{LDAP}->modify( $dn, replace => { cn => $sn, addressBookCN => $sn });
    }
}

#-----------------------------------------------------------------------

#######################################################################################
# Utilities to manipulate the groups						      #
#######################################################################################

=item B<get_gidnumber(cn)>

Get the gidnumber of a group.

=cut

sub get_gidnumber($)
{
    my $this = shift;
    my $cn      = shift;

    my $mesg = $this->{LDAP}->search( base   => $this->{LDAP_BASE},
			              filter => "(&(objectClass=posixGroup)(cn=$cn))",
			              scope  => 'sub',
			              attrs  => [ 'gidNumber' ]
                                    );
    if( $mesg->code() )
    {
       return -1;
    }
    if( $mesg->count() != 1 )
    {
       return -2;
    }
    return $mesg->entry(0)->get_value('gidNumber');
}
#-----------------------------------------------------------------------

=item B<get_fquota_group(dn)>

Returns the file system quota of a group.

EXAMPLE:

  my ( $quotalimit, $quotavalue ) = $oss->get_fquota('cn=10A,ou=group,dc=extis,dc=de');

=cut

sub get_fquota_group($)
{
    my $this = shift;
    my $dn   = shift;
    my $gid  = $this->get_attribute($dn,'gidnumber');
    my $dev  = Quota::getqcarg("/home/groups");
    # my ($q_used,$q_val,$block_hard, $block_timelimit,$inode_curr, $inode_soft, $inode_hard, $inode_timelimit) = Quota::query($dev ,$gid,1);
    my $quota= `/usr/bin/quota -l -w -g $gid | grep $dev`; chomp $quota;
    $quota =~ s/^.*$dev/$dev/g;
    my ($q_dev,$q_used,$q_val,$q_rest) = split /\s+/, $quota;

    if( defined $q_val )
    {
      $q_val = $q_val / 1024;
    }
    else
    {
      $q_val = 0;
    }
    if( defined $q_used && $q_val )
    {
      $q_used = $q_used / 1024;
    }
    else
    {
      $q_used = 0;
    }
    return ($q_val,$q_used);
}
#-----------------------------------------------------------------------

=item B<get_quota_group(dn)>

Returns the mailsystem quota of a group

EXAMPLE:

  my ( $quotalimit, $quotavalue ) = $oss->get_quota_group('cn=10A,ou=group,dc=extis,dc=de');

=cut

sub get_quota_group($)
{
    my $this = shift;
    my $dn = shift;

    my ($q_val,$q_used) = (0,0);

    my $cn = get_name_of_dn($dn);

    my $anf = sub
    {
        my $self = shift;
        my $resp = shift;
        
        $q_val  = $resp->limit("STORAGE") || 0;
        $q_used = $resp->usage("STORAGE") || 0;
	$q_val  = $q_val/1024;
	$q_used = $q_used/1024;
    };

    $this->{IMAP}->set_untagged_callback('quota', $anf);

    my $resp = $this->{IMAP}->getquotaroot($cn);
   
    return ($q_val,$q_used);
}
#-----------------------------------------------------------------------

=item B<get_group(dn)>

Returns the datas of a group.

EXAMPLE:

  my $group = get_group('cn=10,ou=group,dc=extis,dc=de');

=cut

sub get_group
{
    my $this         = shift;
    my $dn           = shift;
    my $mesg = $this->{LDAP}->search( base   => $dn,
	                              scope  => 'base',
           	                      filter => '(objectclass=SchoolGroup)'
                        );
    if( ! $mesg )
    {
        $this->{ERROR}->{text} = "ERROR Could not search the group";
	return undef;
    }
    my $result = $mesg->as_struct;
    #Getting the mail quota
    my($q_val,$q_used) = $this->get_quota_group($dn);
    push @{$result->{$dn}->{quota}},"$q_val";
    push @{$result->{$dn}->{quotaused}},"$q_used";

    #Getting the filesystem quota if any
    my $groupquota    = `mount | grep '/home/groups' | grep -q grpquota && echo -n 1 || echo -n 0`;
    if ($groupquota)
    {
	    ($q_val,$q_used) = $this->get_fquota_group($dn);
	    push @{$result->{$dn}->{fquota}},"$q_val";
	    push @{$result->{$dn}->{fquotaused}},"$q_used";
    }

    return $result->{$dn};
}
#-----------------------------------------------------------------------

=item B<is_group(dn)>

Returns 1 if the dn is a dn of a group.

=cut

sub is_group($)
{
    my $this   = shift;
    my $dn     = shift;

    my $result = $this->{LDAP}->search(
    			base	=> $dn,
			scope	=> 'base',
			filter	=> 'objectclass=posixGroup',
			attrs   => ['dn']
    );
    if( defined $result && $result->count ==1 )
    {
      return 1;
    }
    return 0;
}
#-----------------------------------------------------------------------

=item B<is_class(dn)>

Returns 1 if the dn is a dn of a class.

=cut

sub is_class($)
{
    my $this   = shift;
    my $dn     = shift;

    my $result = $this->{LDAP}->search(
    			base	=> $dn,
			scope	=> 'base',
			filter	=> 'groupType=class',
			attrs   => ['dn']
    );
    if( defined $result && $result->count ==1 )
    {
      return 1;
    }
    return 0;
}
#-----------------------------------------------------------------------

=item B<is_school_group(dn)>

Returns 1 if the dn is a dn of a school group.

=cut

sub is_school_group($)
{
    my $this   = shift;
    my $dn     = shift;

    my $result = $this->{LDAP}->search(
    			base	=> $dn,
			scope	=> 'base',
			filter	=> 'objectclass=schoolGroup',
			attrs   => ['dn']
    );
    if( defined $result && $result->count ==1 ) {
      return 1;
    }
    return 0;
}
#-----------------------------------------------------------------------

=item B<set_fquota_group(dn,MB)>

Sets the file system quota of a group.

EXAMPLE:

  $oss->set_fquota_group('cn=10A,ou=group,dc=extis,dc=de',200);

=cut

sub set_fquota_group
{
    my $this    = shift;
    my $dn      = shift;
    my $fquota  = shift;
    my $fsystem = shift || '/home/groups';

    my $gid     = $this->get_attribute($dn,'gidnumber');
    my $dev     = Quota::getqcarg($fsystem);
    $fquota     *= 1024;
    system("/usr/bin/setquota -g $gid $fquota $fquota 0 0 /home/groups");
#    Quota::setqlim($dev, $gid, $fquota,$fquota, 0, 0, 0, 1);
    
}
#-----------------------------------------------------------------------

=item B<set_quota_group(dn,MB)>

Sets the mail system quota of an user.

EXAMPLE:

  $oss->set_quota_group('cn=10A,ou=group,dc=extis,dc=de',200);

=cut

sub set_quota_group
{
    my $this    = shift;
    my $dn      = shift;
    my $quota   = shift;
    my $cn      = get_name_of_dn($dn);

    my @qarray = ();
    if( $quota )
    {
      @qarray = ("STORAGE", $quota * 1024 );
    }
    $this->{IMAP}->setquota($cn, @qarray);
}
#-----------------------------------------------------------------------

#######################################################################################
# Utilities to manipulate the schools						      #
#######################################################################################

=item B<delete_school(dn)>

Delets a school. Removes all users and groups and LDAP-entries.

EXAMPLE:

 $oss->delete_school('uniqueIdentifier=1008,dc=realschule-bayern,dc=info');

=cut

sub delete_school($)
{
    my $this = shift;
    my $dn = shift;

    if( $dn eq $this->{LDAP_BASE} )
    {
	$this->{ERROR}->{text} = "ERROR can not delete the base institute.";
	return 0;
    }
    my $homebase    = $this->get_school_config('SCHOOL_HOME_BASE',$dn);
    my $domain      = $this->get_school_config('SCHOOL_DOMAIN',$dn);

    foreach my $udn ( @{$this->get_school_users('*',$dn)} )
    {
      my $uid = get_name_of_dn($udn);
      $this->{IMAP}->delete("user/$uid");
    }
    foreach my $gdn ( @{$this->get_school_groups('*',$dn)} )
    {
      my $cn = get_name_of_dn($gdn);
      $this->{IMAP}->delete("$cn");
    }

    if( $homebase && $homebase =~ /^\/home/ )
    {
      system("rm -r $homebase");
    }
    if( $domain && -e "/etc/apache2/vhosts.d/$domain.conf" )
    {
	system("rm /etc/apache2/vhosts.d/$domain.conf");
    }

    #Now we delets the LDAP-entries of the user
    $this->delete_ldap_children($dn);
    $this->{LDAP}->delete($dn);

    #Delete the dns-Entries
    my $mesg = $this->{LDAP}->search(
    		base   => $this->{SYSCONFIG}->{DNS_BASE},
		scope  => 'sub',
		filter => "(|(zoneName=$domain)(pTRRecord=*$domain.))"
    );
    foreach my $entry ($mesg->all_entries)
    {
      $this->{LDAP}->delete($entry->dn);
    }  

    return 1;

}
#-----------------------------------------------------------------------

=item B<add_school_config(KEY,VALUE,DESCRIPTION,TYPE,READONLY,PATH,[SCHOOL_BASE)>

Add a new configuration key to the school configuration.

EXAMPLE:

 $oss->add_school_config('SCHOOL_DOMAIN','school.de','This is the domain name of the school','string','yes','Network/Server/Basis');

=cut

sub add_school_config
{
    my $this   = shift;
    my $key    = shift;
    my $value  = shift;
    my $desc   = shift;
    my $type   = shift;
    my $ro     = shift;
    my $path   = shift;
    my $base   = shift || $this->{SCHOOL_BASE};
    my $mesg;

    if( !defined $key || $key eq '' )
    {
    	$this->{ERROR}->{text} = "Missing configurationKey";
	return 0;
    }
    if( !defined $value || !defined $desc || !defined $type || !defined $ro || !defined $path )
    {
    	$this->{ERROR}->{text} = "Missing some values";
	return 0;
    }
    my $config = Net::LDAP::Entry->new();
    $config->dn('configurationKey='.$key.','.$this->{SYSCONFIG_BASE});
    $config->add( objectclass => [ 'SchoolConfiguration' ],
		  configurationKey	=> $key
		);
    if( $value ne '' )
    {
	$config->add(configurationValue	=> $value);
    }
    if( $desc ne '' )
    {
	$config->add(description	=> $desc);
    }
    if( $type ne '' )
    {
	$config->add(configurationValueType=> $type);
    }
    else
    {
	$config->add(configurationValueType=> 'string');
    }
    if( $ro =~ /^yes/i)
    {
	$config->add(configurationValueRO=> 'yes');
    }
    else
    {
	$config->add(configurationValueRO=> 'no');
    }
    if( $path ne '' )
    {
	$config->add(configurationPath=> 'Network/Server/'.$path);
    }
    $mesg = $this->{LDAP}->add($config);

    if( $mesg->code() ){
       $this->ldap_error($mesg);
       return 0;
    }

    return 1;
}

#-----------------------------------------------------------------------

=item B<delete_school_config>

Deletes a configurations value of a school

EXAMPLE:

 $oss->delete_school_config('SCHOOL_DOMAIN',DN-of-the-school);

=cut

sub delete_school_config
{
    my $this = shift;
    my $key  = shift;
    my $base = shift || $this->{SCHOOL_BASE};
    my $mesg;

    $mesg = $this->{LDAP}->delete( 'configurationKey='.$key.','.$this->{SYSCONFIG_BASE});

    if( $mesg->code() ){
       $this->ldap_error($mesg);
       return 0;
    }

    return 1;
}

=item B<set_school_config(Name,Value,[SchoolDN])>

Setst the value of a school configuration

EXAMPLE:

   $oss->set_school_config('SCHOOL_REGCODE'.'1234-5678-90AB-CDEF-1234');

=cut

sub set_school_config
{
    my $this  = shift;
    my $key   = shift;
    my $value = shift;
    my $base  = shift || $this->{SCHOOL_BASE};

    my $mesg = $this->{LDAP}->modify( 'configurationKey='.$key.','.$this->{SYSCONFIG_BASE} , delete => 'configurationValue');
       $mesg = $this->{LDAP}->modify( 'configurationKey='.$key.','.$this->{SYSCONFIG_BASE} , add => { configurationValue => $value } );

    if( $mesg->code() ){
       $this->ldap_error($mesg);
       return 0;
    }

    return 1;
}
#-----------------------------------------------------------------------

=item B<get_school_config(Name,[SchoolDN])>

Returns an configurations value of a school

EXAMPLE:

 my $domain = $oss->get_school_config('SCHOOL_DOMAIN',DN-of-the-school);

=cut

sub get_school_config
{
    my $this = shift;
    my $key  = shift;
    my $base = shift || $this->{SCHOOL_BASE};
    my $mesg;

    $mesg = $this->{LDAP}->search( base   => 'ou=sysconfig,'.$base,
                                   scope  => 'one',
                                   filter => "configurationKey=$key",
                                 );
    if( $mesg && $mesg->count() == 1)
    {
      return $mesg->entry(0)->get_value('configurationValue');
    }
    return undef;
}
#-----------------------------------------------------------------------

=item B<get_school(school_dn)>

Delivers the settings of a school.

   my $school   = $oss->get_school('uniqueIdentifier=1008,dc=realschule-bayern,dc=info');

=cut

sub get_school
{
    my $this        = shift;
    my $dn          = shift;

    my $mesg = $this->{LDAP}->search( base   => $dn,
                                      scope  => 'base',
                                      filter => '(objectclass=School)'
                        );

    my $result = $mesg->as_struct;
    $this->{LDAP_BASE} = $dn;
    $this->init_sysconfig();

    foreach my $key ( keys %{$this->{SYSCONFIG}} )
    {
      push @{$result->{$dn}->{$key}}, $this->{SYSCONFIG}->{$key};
    }
    return $result;
}
#-----------------------------------------------------------------------

=item B<get_schools([1|0])>

Delivers the DNs or DNS and Names of all schools in the database.

   my @school   = $oss->get_schools();
   In this case the @school list is an array of the DNs of the schools, starting with the LDAP_BASE.

   my @school   = $oss->get_schools(1);
   In this case the @school list is an array of hashes { DNs => o } of the schools,i
   starting with the LDAP_BASE { LDAP_BASE => SCHOOL_NAME }.

=cut

sub get_schools
{
    my $this        = shift;
    my $hash        = shift || 0;
    my %schools     = ();
    my @sorted      = ( { $this->{LDAP_BASE} => $this->get_school_config('SCHOOL_NAME',$this->{LDAP_BASE}) } );
    my @dns         = ( $this->{LDAP_BASE} );

    my $mesg = $this->{LDAP}->search( base   => $this->{LDAP_BASE},
                                      scope  => 'one',
                                      filter => '(objectclass=customer)',
                                      attrs  => ['dn','o']
                        );

    foreach my $entry ( $mesg->entries )
    {
        $schools{$entry->get_value('o')} = $entry->dn();
        push @dns, $entry->dn();
    }
    if( ! $hash )
    {
        return \@dns;
    }
    foreach my $o ( sort {uc($a) cmp uc($b)} keys %schools )
    {
        push @sorted, { $schools{$o} => $o };
    }
    return \@sorted;

}
#-----------------------------------------------------------------------

=item B<get_school_base(oid|dn_of_an_object_in_the_school)>

Returns the base dn of a school. Oid can be the oid of a school or a dn
of an object in the school.

EXAMPLE:

  my $base = $oss->get_school_base('12345');

  my $base = $oss->get_school_base('uid=varkpete,ou=people,dc=extis,dc=de');
  
  my $base = $oss->get_school_base('uid=varkpete,ou=people,uniqueidentifier=12345,dc=extis,dc=de');
  
=cut

sub get_school_base($)
{
    my $this = shift;
    my $oid  = shift;

    if( $oid =~ /$this->{LDAP_BASE}$/i )
    {
      #This  is a DN not an oid
      if( $oid =~ /(uniqueidentifier=.*)/i )
      {
        return $1;
      }
      return $this->{LDAP_BASE};
    }

    my  $mesg = $this->{LDAP}->search( base   => $this->{LDAP_BASE},
                             scope  => 'one',
                             filter => "(&(uniqueidentifier=$oid)(objectclass=School))"
                    );
    if( $mesg && $mesg->count() == 1)
    {
      return $mesg->entry(0)->dn();
    }
    $this->{ERROR}->{text} = "ERROR Can not find a school for the identifier $oid";
    return undef;
}
#-----------------------------------------------------------------------

=item B<get_school_groups(group_type,school_dn)>

Delivers the groups of a school.

   my $all_groups    = $oss->get_school_groups('*');
   my $primarygroups = $oss->get_school_groups('primary');

=cut

sub get_school_groups
{
    my $this        = shift;
    my $type        = shift;
    my $school_base = shift || $this->{SCHOOL_BASE};
    my @dn          = ();

    my $filter      = '(objectclass=*)';

    if( $type ne '*' )
    {
      $filter      = "(&(objectclass=schoolGroup)(grouptype=$type))";
    }

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

#-----------------------------------------------------------------------

=item B<get_school_groups_to_search([UserDN])>

Delivers the lists of the groups of a school with theier descriptions.

   my ($primaries, $classes, $workgroups) = $oss->get_school_groups_to_search();

Delivers the lists of the those groups of a school with theier descriptions in which
the user is member.

   my ($primaries, $classes, $workgroups) = $oss->get_school_groups_to_search('uid=varkpete,ou=people,dc=extis,dc=de');

=cut

sub get_school_groups_to_search
{
    my $this        = shift;
    my $uDN         = shift || undef;

    my @primary     = ();
    my @class       = ();
    my @group       = ();
    my %pri         = ();
    my %cla         = ();
    my %gro         = ();
    my @mygroups    = $this->get_attribute($uDN,'memberOf');

    foreach my $p (@{$this->get_school_groups('primary')})
    {
	my  $desc = $this->get_attribute($p,'description') || $this->get_attribute($p,'role');
	next if( defined $uDN && ! contains($p,\@mygroups) );
	$pri{$desc} = $p;
    }
    foreach my $p (@{$this->get_school_groups('class')} )
    {
	my  $desc = $this->get_attribute($p,'description') || $this->get_attribute($p,'cn');
	next if( defined $uDN && ! contains($p,\@mygroups) );
	$cla{$desc} = $p;
    }
    foreach my $p (@{$this->get_school_groups('workgroup')})
    {
	my $desc = $this->get_attribute($p,'description') || $this->get_attribute($p,'cn');
	my $writerDN = $this->get_attribute($p,'writerDN');
	next if( defined $uDN && ( defined $writerDN && $writerDN ne $uDN ) );
	$gro{$desc} = $p;
    }
    foreach my $desc ( sort {uc($a) cmp uc($b)} keys %pri )
    {
	push @primary,  [ $pri{$desc}, $desc ];
    }
    foreach my $desc ( sort {uc($a) cmp uc($b)} keys %cla )
    {
	push @class,  [ $cla{$desc}, $desc ];
    }
    foreach my $desc ( sort {uc($a) cmp uc($b)} keys %gro )
    {
	push @group,  [ $gro{$desc}, $desc ];
    }
    return (\@primary, \@class, \@group );
}
#-----------------------------------------------------------------------

=item B<get_school_users(role,[school_dn])>

Delivers the users of a school.

   my @all_user = @{$oss->get_school_users('*')};
   my @teachers = @{$oss->get_school_users('teachers')};


=cut

sub get_school_users {
    my $this        = shift;
    my $role        = shift;
    my $school_base = shift || $this->{SCHOOL_BASE};
    my @dn          = ();
    my $filter      = '(objectclass=schoolAccount)';

    if( $role ne '*' )
    {
      $filter      = "(&(objectclass=schoolAccount)(role=$role))";
    }

    my $mesg = $this->{LDAP}->search( base   => 'ou=people,'.$school_base,
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

#-----------------------------------------------------------------------

#######################################################################################
# Utilities to manipulate the workstations / images				      #
#######################################################################################

=item B<add_host_to_zone(hostname,IP-Address,zone)>

Insert a new host into the DNS server and returns the DN of the new or modified entry.

EXAMPLE:

 my $reversHostDN = $oss_base->add_host_to_zone("www.schule.de","192.168.0.2","168.192.IN-ADDR.ARPA");
 my $hostDN       = $oss_base->add_host_to_zone("www","192.168.0.2","schule.de");

=cut

sub add_host_to_zone($$$)
{
    my $this     = shift;
    my $hostname = shift;
    my $ip       = shift;
    my $zone     = shift;
    my $hostDN   = "";

    my $mesg = $this->{LDAP}->search( base    => $this->{SYSCONFIG}->{DNS_BASE},
       				      scope   => 'sub',
				      attrs   => ['dn'],
				      filter  => "(&(relativeDomainName=@)(zoneName=$zone))"
			);
    if( $mesg->code)
    {
         $this->ldap_error($mesg);
         return undef;
    }
    my $base = $mesg->entry(0)->dn;

    if( $zone =~ /((\d+\.)+)IN-ADDR\.ARPA/i )
    { #Adding revers lookup entry
       my @rev_net           = split /\./, $1;
       my @full_host_address = reverse(split( /\./, $ip));
       my @host_address      = ();
       for( my $i=0; $i < 3 - $#rev_net; $i++)
       {
         $host_address[$i] = $full_host_address[$i];
       }
       my $rev_relDN   = join (".", @host_address );
       my $reverse_dn  = 'relativeDomainName='.$rev_relDN.','.$base;
       $mesg = $this->{LDAP}->search(
				  base    => $base,
                                  scope   => 'one',
                                  attrs   => ['pTRRecord'],
                                  filter  => 'relativeDomainName='.$rev_relDN
                             );
       $hostDN = $reverse_dn;
       if( $mesg->code)
       {
	    $this->ldap_error($mesg);
	    return undef;
       }
       elsif( $mesg->count == 0 )
       {  # The entry does not exist yet a new on has to be created
          my $reverse_entry = Net::LDAP::Entry->new();
          $reverse_entry->dn($reverse_dn);
          $reverse_entry->add(    relativeDomainName      => $rev_relDN,
                                  pTRRecord               => "$hostname.",
                                  dNSTTL                  => '172800',
                                  zoneName                => $zone,
                                  objectClass             => ['top', 'dNSZone']
                      );
          $mesg = $this->{LDAP}->add($reverse_entry);
          if($mesg->code)
	  {
	    $this->ldap_error($mesg);
	    return undef;
          }
       }
       else
       {  # The entry is already defined just a new value to pTRRecord
          $mesg = $this->{LDAP}->modify( $reverse_dn, "add" => { "pTRRecord" => "$hostname."});
          if($mesg->code)
          {
	    $this->ldap_error($mesg);
	    return undef;
          }
       }
    }
    else
    {
       $hostDN= 'relativeDomainName='.$hostname.','.$base;
       $mesg = $this->{LDAP}->search(     base    => $base,
                                          scope   => 'one',
                                          attrs   => ['aRecord'],
                                          filter  => 'relativeDomainName='.$hostname
                                     );
       if( $mesg->code)
       {
	    $this->ldap_error($mesg);
	    return undef;
       }
       elsif( $mesg->count == 0 )
       {  # The entry does not exist yet a new on has to be created
          my $hostentry = Net::LDAP::Entry->new();
          $hostentry->dn( $hostDN );
          $hostentry->add(aRecord                 => $ip,
                          relativeDomainName      => $hostname,
                          dNSTTL                  => '172800',
                          zoneName                => $zone,
                          objectClass             => ['top', 'dNSZone']
                     );
         $mesg = $this->{LDAP}->add($hostentry);
         if($mesg->code)
         {
	    $this->ldap_error($mesg);
	    return undef;
         }
       }
       else
       {
          $mesg = $this->{LDAP}->modify( $hostDN, "add" => { aRecord => $ip});
          if($mesg->code)
          {
	    $this->ldap_error($mesg);
	    return undef;
          }
       }
   }
   $this->update_soa($zone);
   return $hostDN;
}
#-----------------------------------------------------------------------

=item B<add_host(FQHN,IP-Address,[MAC-Address,HWconf,MASTER,WLANACCESS])>

Insert a new host into the DNS server and returns the DNs of the created or modified entries.
If MAC-Address is given, an DHCPHost entry will be created too.

EXAMPLE:

 my @hostDNs = $oss->add_host("www.schule.de","192.168.0.2");
or
 my @hostDNs = $oss->add_host("www.schule.de","192.168.0.2","00:1C:42:5A:E5:F6","hwconf2",0);

=cut

sub add_host
{
    my $this    = shift;
    my $fqhn    = shift;
    my $ip      = shift;
    my $mac     = shift || undef;
    my $hwconf  = shift || undef;
    my $master  = shift || undef;
    my $wlan    = shift || undef;
    my @hostDNs = ();

    my ($hostname,$domainname) = split /\./, $fqhn, 2;
    push @hostDNs, $this->add_host_to_zone($hostname,$ip,$domainname);

    # Now we try to create the revers lookup
    my $mesg = $this->{LDAP}->search (   base  => $this->{LDAP_BASE},
                                       filter  => '(&(relativeDomainName=@)(zoneName=*IN-ADDR.ARPA))',
				        attrs  => ['zoneName','dn']
    );
    my @lip = split /\./, $ip;
    foreach my $entry ($mesg->entries)
    {
      my $myzone = 1;
      my $zone   = $entry->get_value('zoneName');
      $zone =~ /^((\d+\.)+)IN-ADDR\.ARPA/i;

      if(defined $1)
      {
        my @ip_parts = reverse(split /\./, $1);
        for( my $i=0; $i < $#ip_parts; $i++ )
	{
	   if( $ip_parts[$i] ne $lip[$i] ){
	     $myzone = 0;
	     last;
	   }
	}
      }
      else
      {
        $this->{ERROR}->{text} = "ERROR Bad IN-ADDR.ARPA zone name: $zone";
	return 0;
      }
      if($myzone)
      {
	push @hostDNs, $this->add_host_to_zone($fqhn,$ip,$zone);
	last;
      }
    }
    # Evtl. we can add this to dhcp too
    if( $mac )
    {
	my $room = $this->get_room_of_ip($ip);
	my $newdn = 'cn='.$hostname.','.$room;
	# create DHCPEntry entry
	my $entry = new Net::LDAP::Entry;
	$entry->dn( $newdn );
	$entry->add( objectClass => [ 'top', 'dhcpHost','dhcpOptions' ,'DHCPEntry','schoolWorkstation' ] );
	$entry->add( dhcpHWAddress   => "ethernet ".$mac,
		 cn              => "$hostname",
		 dhcpStatements  => "fixed-address ".$ip
	       );
	if( $hwconf )
	{
	    $entry->add( configurationValue => 'HW='.$hwconf);
	}
	if( $master )
	{
	    $entry->add( configurationValue => 'MASTER=yes');
	}
	if( $wlan )
	{
	    $entry->add( configurationValue => 'WLANACCESS=yes');
	}
	foreach my $dn ( @hostDNs )
	{
	    $entry->add( dNSZoneDN => "$dn");
	    $this->{LDAP}->modify( $dn , add => { objectClass => "DHCPEntry", dhcpHostDN => $newdn  } );
	}
	my $result =$this->{LDAP}->add($entry);
	push @hostDNs, $newdn;
    }
    return @hostDNs;
}
#-----------------------------------------------------------------------

=item B<delete_host>

Deletes a host with all his entries 

EXAMPLE:

 $oss->delete_host('cn=edv-pc01,cn=Room0,cn=172.17.0.0,cn=config1,cn=schooladmin,ou=DHCP,dc=EXTIS-School,dc=de');

=cut

sub delete_host($)
{
    my $this = shift;
    my $dn   = shift;

    my $entry = $this->get_entry($dn,1);
    if( $dn =~ /^cn=.*/ )
    {
	#delete kiwi-ltsp configure files
	my $hwaddress= $this->get_attribute($dn,'dhcpHWAddress');
	$hwaddress =~ s/ethernet //i;
	$hwaddress = uc($hwaddress);
	if( -e "/srv/tftp/KIWI/config.$hwaddress"){
		system("rm /srv/tftp/KIWI/config.$hwaddress");
	}
	if( -e "/srv/tftp/KIWI/lts.$hwaddress"){
		system("rm /srv/tftp/KIWI/lts.$hwaddress");
	}
	#delete boot file (/srv/tftp/pxelinux.cfg/<MA:CA:DD:RE:SS>)
	$hwaddress =~ s/:/-/g;
	$hwaddress = "01-".lc($hwaddress);
	if( -e "/srv/tftp/pxelinux.cfg/$hwaddress"){
		system("rm /srv/tftp/pxelinux.cfg/$hwaddress");
	}

        my $cn  = $entry->get_value('cn');
	my @dnszonedn = $entry->get_value('dnszonedn');
        foreach my $dns ( @dnszonedn )
	{
	    $this->{LDAP}->delete($dns);
	}
	$this->delete_ldap_children($dn);
	$this->{LDAP}->delete($dn);
	$this->{LDAP}->delete('uid='.$cn.'$,'.$this->{SYSCONFIG}->{COMPUTERS_BASE});
	system("rm -rf /srv/itool/hwinfo/$cn") if( -d '/srv/itool/hwinfo/'.$cn );
	my $udn  = $this->get_user_dn($cn);
        if( $this->is_workstation($udn) )
        { #Now we delete the workstation user
                #Start the plugin
                my $TMP = hash_to_text({ $udn , $this->get_user($udn,[ 'uid', 'cn', 'uidnumber','gidnumber','role' ])});
                chomp $TMP;
                my $TMPFILE = write_tmp_file($TMP);
                system("/usr/share/oss/plugins/plugin_handler.sh del_user $TMPFILE &> /dev/null");
                #delete home
                my $home = $this->get_attribute($udn,'homedirectory');
                if( -d $home && $home =~ /workstations\/$cn$/ )
                {
                    system( "rm -r $home" );
                }
                #Now we delet the user from the groups.
                foreach my $group ( @{$this->get_groups_of_user($udn,1)} )
                {
                  $this->delete_user_from_group($udn,$group);
                }
                $this->delete_ldap_children($udn);
                $this->{LDAP}->delete($udn);
        }

    }

}
#-----------------------------------------------------------------------
=item B<get_user_of_workstation([dn])>

Reports the user which is actually logged on on this workstation

=cut

sub get_user_of_workstation($)
{
    my $this = shift;
    my $dn   = shift;
    my $ip   = $this->get_ip_of_host($dn);

    my $result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{USER_BASE},
                                         filter => "(configurationValue=LOGGED_ON=$ip)",
	                                  scope => 'one',
					 attr   => []
			              );
    if( $result->code != 0)
    {
     	$this->ldap_error($result);
	return 0;
    }
    if( $result && $result->count())
    {
	return $result->entry(0)->dn();
    }
    return undef;
}
=item B<get_user_of_workstation([dn])>


=item B<get_workstations_of_room([dn|Name],hash)>

Lists the workstations of a room; If C<hash> is false only an array of the
dns of the workstations will be reported.

EXAMPLE:

=cut

sub get_workstations_of_room
{
    my $this = shift;
    my $dn   = shift;
    my $hash = shift || 0;
    if( $dn !~ /^cn=Room/ )
    {
	    $dn = $this->get_room_by_name($dn);
    }
    my $result = $this->{LDAP}->search(  base    => $dn,
					 scope   => 'one',
                                         filter  => 'objectclass=dhcpHost'
                           );
    my %ws = %{$result->as_struct};

    if( $hash )
    {
      return \%ws;
    }
    my @dns = ();
    foreach my $dn ( keys %ws )
    {
      push @dns, $dn;
    }
    return \@dns;
}
#-----------------------------------------------------------------------

=item B<add_room($dn,$desc,$hwconf)

Add a new room

=cut

sub add_room($$$)
{
    my $this   = shift;
    my $dn     = shift;
    my $desc   = shift;
    my $hwconf = shift || undef;
    # We have to check if there is realy no description.
    # This may happen if more then one admin works parallel on the OSS
    if( $this->get_attribute($dn,'description') ) {
        $this->{ERROR}->{code} = 'ROOM_DEFINED_ALLREADY';
        $this->{ERROR}->{text} = 'The room has been defined allready.';
    	return 0;
    }
    # We have to check if the room name is uniqe
    if( ! $this->is_unique('room',$desc) )
    {
        $this->{ERROR}->{code} = 'ROOM_NAME_USED_ALLREADY';
        $this->{ERROR}->{text} = 'The room name is used allready.';
    	return 0;
    }
    my $result = $this->{LDAP}->modify( $dn , add => { description          => $desc });
    if( $result->code != 0)
    {
     	$this->ldap_error($result);
	return 0;
    }
    $this->{LDAP}->modify( $dn , add => {
                                         serviceAccesControl => [ 'DEFAULT all:0 proxy:1 printing:1 mailing:1 samba:1',
                                                                  '06:00:1111111 DEFAULT'
                                                                ]
                                        });
    $this->{LDAP}->add( dn => "resourceName=$desc,ou=ResourceObjects,".$this->{SCHOOL_BASE},
    			attrs => [ objectClass => 'OXResourceObject',
				   resourceName => $desc,
				   resourceAvailable => 'TRUE'
				 ]
			);	 
    $this->{LDAP}->modify( "resourceGroupName=Rooms,ou=ResourceObjects,".$this->{SCHOOL_BASE},
    				add => { resourceGroupMember => $desc } );

    my $attrs   = "description $desc\nnetwork ".$this->get_attribute($dn,'dhcprange').
                                 "\nnetmask ".$this->get_attribute($dn,'dhcpnetmask');
    if( $hwconf )
    {
                $result = $this->{LDAP}->modify( $dn ,
                                        add => { configurationValue  => 'HW='.$hwconf });
	$attrs .= "\nhwconf $hwconf";
    }
    # start plugin
    my $TMPFILE = write_tmp_file($attrs);
    system("/usr/share/oss/plugins/plugin_handler.sh add_room $TMPFILE &> /dev/null");
    return 1;
}

#-----------------------------------------------------------------------

=item B<delete_room($dn)

Remove a room with all workstations and resource and other entries

=cut

sub delete_room($)
{
    my $this   = shift;
    my $dn     = shift;
    my $desc   = $this->get_attribute($dn,'description');

    foreach my $dn ( @{$this->get_workstations_of_room($dn)} )
    {
            $this->delete_host($dn);
    }
    $this->delete_ldap_children($dn);
    $this->{LDAP}->modify( $dn , delete => { 'description' => [] } );
    $this->{LDAP}->modify( $dn , delete => { 'serviceAccesControl' => [] } );
    $this->{LDAP}->delete( "resourceName=$desc,ou=ResourceObjects,".$this->{SCHOOL_BASE} );
    $this->{LDAP}->modify( "resourceGroupName=Rooms,ou=ResourceObjects,".$this->{SCHOOL_BASE},
                                 delete => { resourceGroupMember => $desc } );
    # start plugin
    my $TMPFILE = write_tmp_file("description $desc\n");
    system("/usr/share/oss/plugins/plugin_handler.sh del_room $TMPFILE &> /dev/null");
    return 1;

}

#-----------------------------------------------------------------------

=item B<get_free_rooms()>

Returns the rooms which are not named.

EXAMPLE:

  my $rooms = $oss->get_free_rooms();

=cut

sub get_free_rooms($)
{
    my $this   = shift;

    my $result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DHCP_BASE},
                                       scope   => 'sub',
                                       filter  => '(&(Objectclass=SchoolRoom)(!(description=*)))'
                              );
    return $result->as_struct;

}
#-----------------------------------------------------------------------

=item B<get_rooms(undef|'all'|'clients','ownerDN') >

Returns the rooms.
   undef => all registered rooms
   all   => all registered rooms inkl. SERVER_NET & ANON_DHCP
   clients => all registered rooms inkl. ANON_DHCP

EXAMPLE:

  my $rooms = $oss->get_rooms();

=cut

sub get_rooms()
{
    my $this   = shift;
    my $all    = shift || undef ;
    my $filter = '(&(Objectclass=SchoolRoom)(description=*)(&(!(description=ANON_DHCP))(!(description=SERVER_NET))))';
    if( defined $all && $all eq 'all' )
    {
	    $filter = '(&(Objectclass=SchoolRoom)(description=*))'
    }
    elsif( defined $all && $all eq 'clients' )
    {
	    $filter = '(&(Objectclass=SchoolRoom)(description=*)(!(description=SERVER_NET)))';
    }
    elsif( defined $all && $all =~ /^uid=.*/ )
    {
	$filter = "(&(Objectclass=SchoolRoom)(writerDN=$all))"
    }

    my $result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DHCP_BASE},
                                       scope   => 'sub',
                                       filter  => $filter
                              );
    return $result->as_struct;

}
#-----------------------------------------------------------------------

=item B<get_room_by_name(RoomName)

Returns the dn of a room

EXAMPE:

    my $dn = $oss->get_room_by_name("edv");

=cut

sub get_room_by_name($)
{
    my $this   = shift;
    my $name   = shift;

    my $result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DHCP_BASE},
                                       scope   => 'sub',
                                       filter  => "(&(Objectclass=SchoolRoom)(description=$name))",
					attrs  => '[dn]'
                              );
    if( $result && $result->count())
    {
	return $result->entry(0)->dn();
    }
    return undef;
}
#-----------------------------------------------------------------------

=item B<get_room_of_ip(IP-address) >

Returns the DN or the attributes of the school room containing the given IP-address.

EXAMPLE:

	my $roomDN = $oss->get_room_of_ip(172.16.3.20);

=cut

sub get_room_of_ip
{
    my $this   = shift;
    my $ip     = shift;

    my $result = $this->{LDAP}->search(  base    => $this->{SYSCONFIG}->{DHCP_BASE},
					 scope   => 'sub',
					 filter  => '(objectClass=schoolRoom)'
                           );

    if( $result && $result->count())
    {
	foreach my $entry ( $result->entries )
	{
		my $r = $entry->get_value('dhcpRange');
		my $m = $entry->get_value('dhcpNetMask');
		my $block = new Net::Netmask($r.'/'.$m );
		next if ( !defined $block );
		if( $block->match($ip) )
		{
			return $entry->dn;
		}
	}
    }
    return undef;
}
#-----------------------------------------------------------------------

=item B<get_wlan_workstations() >

Returns the labeled list of WLAN workstations.

EXAMPLE:

  my $pcs    = $oss->get_workstations(HASH);

=cut

sub get_wlan_workstations
{
	my $this     = shift;
	my $hash     = shift || 0;
	my @WLANPCS  = ('no','all');
	my %tmp	     = ();
	my %WLAN     = ();
	
	my $result = $this->{LDAP}->search(  base    => $this->{SYSCONFIG}->{DHCP_BASE},
	    				 scope   => 'sub',
	    				 filter  => "(&(objectClass=schoolWorkstation)(cValue=WLANACCESS=yes))",
	    				 attrs   => [ 'cn','dhcpHWAddress' ]
	                       );
	foreach( $result->entries )
	{
		my $HW = uc($_->get_value('dhcpHWAddress'));
		$HW =~ s/ethernet //i;
		$HW =~ s/:/-/g;
		$tmp{$_->get_value('cn')} = $HW;
		$WLAN{$HW} = $_->get_value('cn');
	}
	return \%WLAN if( $hash );
	foreach( sort {uc($a) cmp uc($b)} keys %tmp )
	{
		push @WLANPCS, [ $tmp{$_} , $_ ];
	}
	return \@WLANPCS;
}
#-----------------------------------------------------------------------

=item B<get_workstations(dn) >

Returns the workstations of a school.

EXAMPLE:

  my $pcs    = $oss->get_workstations();

=cut

sub get_workstations
{
    my $this   = shift;
    my $dn     = shift;
    
    my $result = $this->{LDAP}->search(  base    => $this->{SYSCONFIG}->{DHCP_BASE},
					 scope   => 'sub',
					 filter  => "(objectClass=schoolWorkstation)"
                           );
    if( $result  && $result->count() )
    {
      return $result->as_struct;
    }
    return undef;
}
#-----------------------------------------------------------------------

=item B<get_workstation_users([dn|Name])>

Returns the workstation users in a room.

EXAMPLE:

   my $users  = $oss->get_workstation_users('edv');

=cut
sub get_workstation_users
{
    my $this   = shift;
    my $room   = shift;
    my @users  = ();
    if( $room =~ /^cn=Room/ )
    {
	    $room = $this->get_attribute($room,'description');
    }
    my $result = $this->{LDAP}->search (  # perform a search
                           base   => $this->{SYSCONFIG}->{USER_BASE},
                           scope  => "one",
                           attrs => ['dn'],
                           filter => "(&(role=workstations)(uid=$room-*))"
                          );
    foreach my $entry ( $result->all_entries )
    {
        push @users, $entry->dn();
    }
    return \@users;
}
#-----------------------------------------------------------------------

=item B<set_room_access_list(dn,accesslist)>

Sets the room's access list

EXAMPLE

   my $dn    = $oss->get_room_of_ip('192.168.2.23');
   my $acls  =  {
		    'DEFAULT' => {
                                    'all'      => 0,
                                    'printing' => 1,
                                    'mailing'  => 1,
                                    'samba'    => 1,
                                    'proxy'    => 1
                                  },
                    '06:00' => {
                                     'DEFAULT' => 1
                               },
		    '12:00' => {
                                    'all'      => 1,
                                    'printing' => 1,
                                    'mailing'  => 1,
                                    'samba'    => 1,
                                    'proxy'    => 1
                                  },
                    '13:00' => {
                                     'DEFAULT' => 1
                               },
		};
    $oss->set_room_access_list($dn,$acls);
=cut

sub set_room_access_list($$)
{
    my $this   = shift;
    my $dn     = shift;
    my $acls   = shift;

    #First we delete all acls
    $this->{LDAP}->modify( $dn , delete => [ 'serviceAccesControl' ] );

    my $entry = $this->get_entry($dn,1);
    foreach my $key ( keys(%$acls) )
    {
    	if( $acls->{$key}->{DEFAULT} )
	{
	    $entry->add( serviceAccesControl => "$key DEFAULT" );
	}
    	elsif( defined $acls->{$key}->{ClientControl} )
	{
	    $entry->add( serviceAccesControl => "$key ClientControl:".$acls->{$key}->{ClientControl} );
	}
	else
	{
	    my $line = $key.
	               ' all:'.$acls->{$key}->{all}.
	    	       ' proxy:'.$acls->{$key}->{proxy}.
	    	       ' printing:'.$acls->{$key}->{printing}.
	    	       ' mailing:'.$acls->{$key}->{mailing}.
	    	       ' samba:'.$acls->{$key}->{samba};
	    $entry->add( serviceAccesControl => $line );
	}
    }
    $entry->update( $this->{LDAP} );
}
#-----------------------------------------------------------------------

=item B<get_room_access_list(dn) >

Returns the room's service access list.

EXAMPLE:

  my $dn    = $oss->get_room_of_ip('192.168.2.23');
  my %sacls = %{$oss->get_room_access_list($dn)};

  print "Default Service Acces Status ".$sacls->{DEFAULT}."\n"; 
  foreach my $time ( sort(keys(%sacls)) ) {
    next if $time eq 'DEFAULT';
    print "Service Acces Status at $time: ".$sacls->{time}->{printing}."\n"; 
  }  

=cut

sub get_room_access_list($)
{
    my $this   = shift;
    my $dn     = shift;
    my %acls   = ();

    my $result = $this->{LDAP}->search(  base    => $dn,
					 scope   => 'base',
                                         filter  => 'objectclass=schoolRoom',
					 attrs   => [ 'serviceAccesControl' ]
                           );
    if( $result && $result->count() )
    {
	my @acls  =  $result->entry(0)->get_value('serviceAccesControl');
	foreach my $acl (@acls)
	{
	    my ( $time, $value ) = split / /,$acl,2;
	    if( $value eq 'DEFAULT' )
	    {
	    	$acls{$time}  = 'DEFAULT';
	    }
	    else
	    {
		next if ( defined $acls{$time} );
	        foreach my $access ( split / /,$value )
	        {
	            my ($k,$v)   = split /:/,$access;
	            $acls{$time}->{$k} = $v;
	        }
	    }
	}
	return \%acls;
    }
    return undef;
}
#-----------------------------------------------------------------------

=item B<get_room_name(dn) >

Returns the name (description) of the room.

EXAMPLE:

  my $dn   = $oss->get_room_of_ip('192.168.2.23');
  my $room = $oss->get_room_name($dn);

=cut

sub get_room_name($)
{
    my $this   = shift;
    my $dn     = shift;

    return $this->get_attribute($dn,'description');
}    
#-----------------------------------------------------------------------

=item B<get_room_access_state(dn) >

Returns the access state of the room.

EXAMPLE:

  my $dn   = $oss->get_room_of_ip('192.168.2.23');
  my ($all, $mail, $print, $proxy, $samba) = $oss->get_room_access_state($dn);

=cut

sub get_room_access_state($)
{
    my $this   = shift;
    my $dn     = shift;
    my $all    = undef;
    my $nw     = $this->get_attribute($dn,'dhcpRange').'/'.$this->get_attribute($dn,'dhcpNetMask');
    if( $this->{SYSCONFIG}->{SCHOOL_ISGATE} eq 'yes' )
    {
    	$all    = `/usr/sbin/oss_get_access_state $nw all    `;
    }
    my $mail   = `/usr/sbin/oss_get_access_state $nw mailing `;
    my $print  = `/usr/sbin/oss_get_access_state $nw printing`;
    my $samba  = `/usr/sbin/oss_get_access_state $nw samba   `;
    my $proxy  = `/usr/sbin/oss_get_access_state $nw proxy   `;
    return ( $all, $mail, $print, $proxy, $samba );
}
#-----------------------------------------------------------------------

=item B<set_room_access_state(dn,what,state);

Sets the access state for a service in a room. Avaiable values for what:
	all		Masquerading for the room
	proxy		Proxy access for the room
	printig		Printserver access for the room
	mailing		Mailserver access for the room
	samba		Windows login access for the room

EXAMPLE:

   $oss->set_room_access_state($dn,'mail',0);

=cut

sub set_room_access_state
{
    my $this   = shift;
    my $dn     = shift;
    my $what   = shift;
    my $state  = shift;
    my $myip   = shift || '';
    my $nw     = $this->get_attribute($dn,'dhcpRange').'/'.$this->get_attribute($dn,'dhcpNetMask');
    #TODO Check if myip is in the room
    #TODO Check if nw is a network (room does exist)
    #TODO Return 0 or 1 dep. on result
    if( $what eq 'all' && $this->{SYSCONFIG}->{SCHOOL_ISGATE} ne 'yes' )
    {
	return;
    }
    system("/usr/sbin/oss_set_access_state $state $nw $what $myip");
}
=item B<get_workstation(IP-Address|HW-Address) >

Returns the workstation with given IP- or Hardware-Address or name.

EXAMPLE:

  my $dn   = $oss->get_workstation('192.168.2.23');

=cut

sub get_workstation
{
    my $this   = shift;
    my $ip     = shift;
    my $hash   = shift || 0;

    my $result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DHCP_BASE},
                                        filter => "(&(|(dhcpHWAddress=ethernet $ip)(dhcpStatements=fixed-address $ip)(cn=$ip))(objectclass=schoolworkstation))",
                        );
    if( $result && $result->count() )
    {
      if( $hash )
      {
        return $result->as_struct;
      }
      return $result->entry(0)->dn;
    }

    return undef;

}
#-----------------------------------------------------------------------

=item B<update_soa(zone)>

Updates the soa record of a zone

EXAMPLE:

    $oss->update_soa('schule.de');
    $oss->update_soa("168.192.IN-ADDR.ARPA");

=cut

sub update_soa
{
  my $this   = shift;
  my $zone   = shift;

  # get out SOA for rev Zone and increase serial number
  my $mesg = $this->{LDAP}->search(     base   => $this->{LDAP_BASE},
                                        scope  => 'sub',
                                        filter => "(&(zoneName=$zone)(relativeDomainName=@))"
                                  );
  if( $mesg->code)
  {
    $this->ldap_error($mesg);
    return undef;
  }
  elsif( $mesg->count == 0)
  {
    $this->{ERROR} = "No such zone: $zone\n";
    return undef;
  }

  my $zone_entry = $mesg->entry(0);
  my $soa        = $zone_entry->get_value("sOARecord");
  my @soa        = split(/ /,$soa);
  my $timestamp  = $soa[2];
  my $sernr      = substr($timestamp, 8, 2) || 1;
  my $timenr     = substr($timestamp, 0, 8);
  my $timenow    = strftime("%Y%m%d",localtime);

  if( $timenr eq $timenow )
  {
    $sernr++;
  }
  else
  {
    $timenr = $timenow;
  }

  $zone_entry->replace( sOARecord =>
                  $soa[0]." ".$soa[1]." ".$timenr.$sernr." ".
                  $soa[3]." ".$soa[4]." ".$soa[5]." ".$soa[6]);

  $mesg = $zone_entry->update( $this->{LDAP} );
  if($mesg->code)
  {
    $this->ldap_error($mesg);
    return undef;
  }
  return 1;
}
#-----------------------------------------------------------------------

=item B<get_computer_config_value>

Returns a computer configuration value.

EXAMPLE:

 my $VALUE = $oss->get_computer_config_value('PART1_ProductID','hwconf1');

=cut

sub get_computer_config_value($$)
{
    my $this = shift;
    my $key  = shift;
    my $conf = shift;

    return $this->get_config_value('configurationKey='.$conf.','.$this->{SYSCONFIG}->{COMPUTERS_BASE},$key);

}
#-----------------------------------------------------------------------

=item B<get_HW_configurations>

Returns a list of the avaiable hardware configurations.

EXAMPLE:

 my $VALUE = $oss->get_HW_configurations(1);

=cut

sub get_HW_configurations
{
    my $this  = shift;
    my $empty = shift || 0;
    my $result   = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{COMPUTERS_BASE},
                                  scope  => 'one',
                                  filter => "(&(Objectclass=schoolConfiguration)(configurationValue=TYPE=HW))",
                                  attrs  => ['configurationKey','description']
                                );
    my @hw = ();
    if( $empty )
    {
      push @hw , [ '-' , '-----' ];
    }
    foreach my $entry ($result->all_entries) {
	my $desc = $entry->get_value('description') || $entry->get_value('configurationKey');
	push @hw ,[ $entry->get_value('configurationKey') , $desc ]; 
    }
    return \@hw;
}
#-----------------------------------------------------------------------

=item B<get_new_HW_id>

Returns the .

EXAMPLE:

  my $newHW = $oss->get_new_HW_id;

=cut

sub get_new_HW_id()
{
    my $this    = shift;
    my @hw      = ();
    my $count   = 1;

    my $result  = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{COMPUTERS_BASE},
                                  scope  => 'one',
                                  filter => "(&(Objectclass=schoolConfiguration)(configurationValue=TYPE=HW))",
                                  attrs  => ['configurationKey']
                                );
    foreach my $entry ($result->all_entries) {
	my $hw = $entry->get_value('configurationKey');
	$hw =~ /^hwconf(\d+)/;
	push @hw , $1; 
    }
    my @lconf   = sort  {$a <=> $b} @hw;
    if( $#lconf > -1 )
    {
      $count = $lconf[$#lconf] + 1;
    }
    return 'hwconf'.$count;

}

#-----------------------------------------------------------------------

=item B<add_new_HW(Description)>

Returns the .

EXAMPLE:

  my $newHW = $oss->add_new_HW('Very good new Workstations');

=cut

sub add_new_HW()
{
    my $this    = shift;
    my $desc    = shift;
   
    if( ! $desc ) 
    {
    	$this->{ERROR}->{text} = "The description must not be empty";
        $this->{ERROR}->{code} = "EMPTY-DESCRIPTION";
	return 0;
    }
    my $key     = $this->get_new_HW_id();
    my $result  = $this->{LDAP}->add(
                    dn => 'configurationKey='.$key.','.$this->{SYSCONFIG}->{COMPUTERS_BASE},
                    attrs =>
                      [
                         objectClass        => [ 'top' , 'SchoolConfiguration' ],
                         configurationKey   => $key,
                         configurationValue => 'TYPE=HW',
                         configurationValue => 'WSType=FatClient',
                         description        => $desc
                      ]
              );
     return $key;

}

#-----------------------------------------------------------------------
=item B<get_free_mobile_rooms>

Returns the list of free mobile rooms 

EXAMPLE:

  my $rooms = $oss->get_free_mobile_rooms();

=cut
sub get_free_mobile_rooms()
{
	my $this = shift;
	my @rooms= ();
	my $filter = '(|(configurationValue=MAY_CONTROL=@teachers)(configurationValue=MAY_CONTROL='.$this->{aDN}.')))';
	if( $this->is_admin($this->{aDN}) )
	{
		$filter = ')';
	}

	my $result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DHCP_BASE},
                             filter => '(&(Objectclass=SchoolRoom)(description=*)(!(configurationValue=NO_CONTROL))(!(configurationValue=CONTROLLED_BY=*))'.
                                       $filter,
                             attrs  => ['description']
                            );
	foreach ( $result->entries )
	{
		push @rooms, $_->get_value('description');
	}
	@rooms = sort {uc($a) cmp uc($b)} @rooms;
	return \@rooms;
}

#-----------------------------------------------------------------------
=item B<get_controlled_mobile_rooms>

Returns the list of controlled mobile rooms

EXAMPLE:

  my $rooms = $oss->get_controlled_mobile_rooms();

=cut
sub get_controlled_mobile_rooms()
{
        my $this = shift;
        my @rooms= ();
	my $filter = '(|(configurationValue=MAY_CONTROL=@teachers)(configurationValue=MAY_CONTROL='.$this->{aDN}.')))';
	if( $this->is_admin($this->{aDN}) )
	{
		$filter = ')';
	}

        my $result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DHCP_BASE},
                             filter => '(&(Objectclass=SchoolRoom)(description=*)(configurationValue=CONTROLLED_BY=*)'.
				     	$filter, 
                             attrs  => ['description','configurationValue']
                            );

        foreach ( $result->entries )
        {
                my $dn = "";
                foreach( $_->get_value('configurationValue') )
                {
                        if( /^CONTROLLED_BY=(.*)/)
                        {
                                $dn = $1;
                                last;
                        }
                }
                push @rooms, $_->get_value('description').' '.$this->get_attribute($dn,'cn');
        }
        #@rooms = sort @rooms;
        return \@rooms;
}

#-----------------------------------------------------------------------
=item B<select_mobile_room(RoomName,[UserDN])>

Selects the mobil room for a user. If no UserDN is given the session user is the controller.

EXAMPLE:

	$this->select_mobile_room('edv');
	
=cut

sub select_mobile_room
{
	my $this = shift;
	my $room = shift;
	my $dn  =  shift || $this->{aDN};

	$this->{LDAP}->modify( $this->get_room_by_name($room), add=>{ configurationValue => "CONTROLLED_BY=$dn" } );
}

#-----------------------------------------------------------------------
=item B<free_mobile_room(RoomName)>

Sets a mobile room free.

EXAMPLE:
	$this->free_mobile_room('edv');
=cut

sub free_mobile_room
{
	my $this = shift;
	my $room = shift;
	my $dn   = $this->get_room_by_name($room);
	my @cValues= ();

	my $result = $this->{LDAP}->search( base => $dn, scope => 'base', filter => 'objectclass=*', attrs => 'configurationValue' );

	foreach( $result->entry(0)->get_value('configurationValue' ) )
	{
		if( ! /^CONTROLLED_BY=/ )
		{
			push @cValues, $_;
		}
	}
	$this->{LDAP}->modify( $dn , replace => { configurationValue => \@cValues } );
}

#-----------------------------------------------------------------------
=item B<get_room_control_state>

Returns the state of the control settings of a room.

EXAMPLE:

  my ( $control_mode, $controlled_by, $controllers ) = $oss->get_room_control_state("cn=Room2,cn=172.16.0.0,cn=config1,cn=schooladmin,ou=DHCP,dc=extis,dc=edu");

  print "Mode of the room control: ".$control_mode."\n";
  print "The room is actually controlled by: ".$controlled_by."\n";
  foreach my $dn (@{$controllers})
  {
    my $cn = $oss->get_attribute($dn,'cn');
    print "The room may controlled by:".$cn."\n";
  }

=cut

sub get_room_control_state($)
{
    my $this        = shift;
    my $room        = shift;
    my $control     = 'in_room_control';
    my $controlled  = '';
    my @controllers = ();
    my @configs     = $this->get_attribute($room,"configurationvalue"); 

    foreach my $i ( @configs )
    {
        if( $i eq 'NO_CONTROL' )
        {
            $control = 'no_control' ;
            last;
        }
        elsif( $i eq 'MAY_CONTROL=@teachers' )
        {
            $control = 'all_teacher_control' ;
        }
        elsif( $i =~ /MAY_CONTROL=(.*)/i)
        {
            $control = 'teacher_control' ;
	    push @controllers, $1;
        }
	elsif( $i =~ /^CONTROLLED_BY=(.*)/i )
	{
	    $controlled = $1;
	}
    }
    return ($control, $controlled, \@controllers);
}

#-----------------------------------------------------------------------
=item B<is_online(dn)>

Returns true if the workstation online is. E.m. the configurationValue STATE=on is set.

=cut

sub is_online($)
{
    my $this   = shift;
    my $dn     = shift;

    my $result = $this->{LDAP}->search(
    			base	=> $dn,
			scope	=> 'base',
			filter	=> 'configurationValue=STATE=on',
			attrs   => ['dn']
    );
    if( defined $result && $result->count ==1 )
    {
      return 1;
    }
    return 0;
}

#-----------------------------------------------------------------------
=item B<get_ip_of_host>

Returns the IP of a host

=cut

sub get_ip_of_host($)
{
    my $this   = shift;
    my $dn     = shift;

    my $result = $this->{LDAP}->search(
    			base	=> $dn,
			scope	=> 'base',
			filter	=> 'objectclass=*',
			attrs   => ['dhcpStatements']
    );
    if( !$result->code && $result->count )
    {
    	foreach( $result->entry(0)->get_value('dhcpStatements') )
	{
		if( /fixed-address (.*)/ )
		{
			return $1;
		}
	}
    }
    return undef;
}
#-----------------------------------------------------------------------
=item B<get_host(Address)>

Returns the DN of a host. The argument can be the IP or the MAC address

=cut

sub get_host($)
{
    my $this   = shift;
    my $add    = shift;

    my $result = $this->{LDAP}->search(
                        base    => $this->{SYSCONFIG}->{DHCP_BASE},
                        scope   => 'sub',
                        filter  => "(&(objectclass=dhcpHost)(|(dhcpHWAddress=ethernet $add)(dhcpStatements=fixed-address $add)))",
                        attrs   => ['dn']
    );
    if( !$result->code && $result->count )
    {
        return $result->entry(0)->dn;
    }
    return undef;
}

#######################################################################################
# Create, Read and Modify Vendor Objects					      #
#######################################################################################

=item B<create_vendor_object(dn,vendor,key,value,[description])>

Create a new vendor object for a school object.

EXAMPLE:

    $oss->create_vendor_object( 'uid=admin,ou=people,dc=EXTIS-School,dc=de',
				'extis','rights',['read','write']
    );

=cut

sub create_vendor_object
{
    my $this   = shift;
    my $dn     = shift;
    my $vendor = shift;
    my $key    = shift;
    my $value  = shift;
    my $description  = shift || undef;
    my $vbase  = 'o='.$vendor.','.$dn;
    my $kbase  = 'configurationKey='.$key.','.$vbase;
    
    if( $this->exists_dn($dn) != 1)
    {
      return undef;
    }
    my $state = $this->exists_dn($vbase);
    if( $state == 0 )
    {
      $this->{LDAP}->add( dn =>  $vbase,
      			attr => [
          		      objectclass => [ 'top', 'organization' ],
          	              o           => $vendor
          		      ]
                 );
    }
    elsif( $state < 0 )
    {
      return undef;
    }
    $state = $this->exists_dn($kbase);
    if( $state == 0 )
    {
      $this->{LDAP}->add( dn =>  $kbase,
      			attr => [
          		      objectclass        => [ 'top', 'schoolConfiguration' ],
          	              configurationKey   => $key,
          		      configurationValue => $value
          		      ]
                 );
    }
    elsif( $state == 1 )
    {
      #TODO The delete is only provisional 
      $this->{LDAP}->modify( $kbase, delete => ['configurationValue'] );
      $this->{LDAP}->modify( $kbase, add    => { configurationValue => $value } );
    }
    $this->{LDAP}->modify( $kbase, delete => ['description'] );
    if( defined $description )
    {
	    $this->{LDAP}->modify( $kbase, add    => { description => $description } );
    }
}
#-----------------------------------------------------------------------

=item B<get_vendor_object(dn,vendor,key)>

Gets the vendor object value(s) of an object.

EXAMPLE:

	my $values = $oss->get_vendor_object( 'uid=admin,ou=people,dc=EXTIS-School,dc=de', 'extis','rights');

	foreach( @$values )
	{
		print $_;
	}

=cut

sub get_vendor_object($$$)
{
    my $this   = shift;
    my $dn     = shift;
    my $vendor = shift;
    my $key    = shift;
    my $result = {};
    my @leer   = ();
    my $vbase  = 'o='.$vendor.','.$dn;
    my $kbase  = 'configurationKey='.$key.','.$vbase;
    
    my $mesg = $this->{LDAP}->search( base   => $kbase,
    				      scope  => 'base',
          			      filter => 'objectclass=*'
    );
    if( defined $mesg && $mesg->count )
    {
	my $res = $mesg->entry(0);
	if( $res->exists( "configurationvalue" ) )
	{
        	my @t = $res->get_value( "configurationvalue" );
		return \@t;
	}
	else
	{
		return [];
	}
    }
    return [];
}

#-----------------------------------------------------------------------

=item B<check_vendor_object(dn,vendor,key,value)>

Checks if the vendor object contains a value.

EXAMPLE:

	if( $oss->get_vendor_object( 'uid=admin,ou=people,dc=EXTIS-School,dc=de', 'extis','rights','write') )
	{
		print "You may write";
	}

=cut

sub check_vendor_object($$$$)
{
    my $this   = shift;
    my $dn     = shift;
    my $vendor = shift;
    my $key    = shift;
    my $value  = shift;
    my $result = {};
    my $vbase  = 'o='.$vendor.','.$dn;
    my $kbase  = 'configurationKey='.$key.','.$vbase;
    
    my $mesg = $this->{LDAP}->search( base   => $kbase,
    				    scope  => 'base',
          			    filter => "configurationValue=$value"
    );
    if( defined $mesg && $mesg->count )
    {
	return 1;
    }
    return 0;
}
#-----------------------------------------------------------------------

=item B<get_vendor_object_as_hash(dn,vendor,key)>

Gets the vendor object value(s) of an object.

EXAMPLE:

    $o = $oss->get_vendor_object_as_hash( 'uid=admin,ou=people,dc=EXTIS-School,dc=de',
				'extis','rights'
    );
    print $o->{'uid=admin,ou=people,dc=EXTIS-School,dc=de'}->{configurationkey};
    print $o->{'uid=admin,ou=people,dc=EXTIS-School,dc=de'}->{configurationvalue};

=cut

sub get_vendor_object_as_hash
{
    my $this   = shift;
    my $dn     = shift;
    my $vendor = shift;
    my $key    = shift;
    my $result = {};
    my $vbase  = 'o='.$vendor.','.$dn;
    my $kbase  = 'configurationKey='.$key.','.$vbase;
    
    my $mesg = $this->{LDAP}->search( base   => $kbase,
    				    scope  => 'base',
          			    filter => 'objectclass=*'
    );
    if( defined $mesg && $mesg->count )
    {
        my $res = $mesg->as_struct;
        $result->{$dn}->{configurationkey}   = $res->{$kbase}->{configurationkey};
        $result->{$dn}->{configurationvalue} = $res->{$kbase}->{configurationvalue};
    }
    return $result;
}
#-----------------------------------------------------------------------

=item B<delete_vendor_object(dn,vendor,key)>

Delets a vendor object of a school object.

EXAMPLE:

    $oss->delete_vendor_object( 'uid=admin,ou=people,dc=EXTIS-School,dc=de',
				'extis','rights'
    );

=cut

sub delete_vendor_object($$$)
{
  my $this   = shift;
  my $dn     = shift;
  my $vendor = shift;
  my $key    = shift;
  my $vbase  = 'o='.$vendor.','.$dn;
  my $kbase  = 'configurationKey='.$key.','.$vbase;

  my $mesg = $this->{LDAP}->delete( $kbase );

}
#-----------------------------------------------------------------------
  
=item B<add_value_to_vendor_object(dn,vendor,key,value)>

Add one new value to a vendor object. If the vendor object do not exists this
will be created.

EXAMPLE:

    $oss->add_value_to_vendor_object( 'uid=admin,ou=people,dc=EXTIS-School,dc=de', 'extis','rights','read');

=cut

sub add_value_to_vendor_object($$$$)
{
	my $this   = shift;
	my $dn     = shift;
	my $vendor = shift;
	my $key    = shift;
	my $value  = shift;
	my $vbase  = 'o='.$vendor.','.$dn;
	my $kbase  = 'configurationKey='.$key.','.$vbase;
	
	if( ! $this->exists_dn($dn) )
	{
	  return undef;
	}
	if( ! $this->exists_dn($kbase) )
	{
		$this->create_vendor_object($dn,$vendor,$key,$value);
	}
	else
	{
		$this->{LDAP}->modify( $kbase, add => { configurationvalue => $value } );
	}
}
#-----------------------------------------------------------------------
  
=item B<delete_value_from_vendor_object(dn,vendor,key,value)>

Add one new value to a vendor object. If the vendor object do not exists this
will be created.

EXAMPLE:

    $oss->delete_value_from_vendor_object( 'uid=admin,ou=people,dc=EXTIS-School,dc=de', 'extis','rights','read');

=cut

sub delete_value_from_vendor_object($$$$)
{
	my $this   = shift;
	my $dn     = shift;
	my $vendor = shift;
	my $key    = shift;
	my $value  = shift;
	my $vbase  = 'o='.$vendor.','.$dn;
	my $kbase  = 'configurationKey='.$key.','.$vbase;
	
	if( ! $this->exists_dn($dn) )
	{
	  return undef;
	}
	if( ! $this->exists_dn($kbase) )
	{
		$this->create_vendor_object($dn,$vendor,$key,$value);
	}
	else
	{
		$this->{LDAP}->modify( $kbase, delete => { configurationvalue => $value } );
	}
}
#-----------------------------------------------------------------------
  
=item B<search_vendor_object_for_vendor(vendor[,object])>

Search the vendor objects with given vendor key and value;

EXAMPLE:

    my $obj = $oss->search_vendor_object_for_vendor( 'extis','uid=pv,ou=people,dc=extis,dc=de');
    print $obj->[0];

=cut

sub search_vendor_object_for_vendor
{
	my $this   = shift;
	my $vendor = shift;
	my $base   = shift || $this->{SCHOOL_BASE};
	my @obj    = ();
	my $result = $this->{LDAP}->search( 
			base   => $base, 
			scope  => 'sub',
			filter => "(o=$vendor)",
			attrs  => []
			);
	if( $result->code )
	{
		return undef;
	}
	foreach my $i ( $result->entries )
	{
		my $res = $this->{LDAP}->search( 
			base   => $i, 
			scope  => 'one',
			filter => '(objectclass=schoolConfiguration)',
			attrs  => []
			);
		foreach ( $res->entries )
		{
			push @obj, $_->dn;
		}
	}
	return \@obj;
}
#-----------------------------------------------------------------------
  
=item B<search_vendor_object(vendor,key,value)>

Search the vendor objects with given vendor key and value;

EXAMPLE:

    my $obj = $oss->search_vendor_object( 'extis','rights','read');
    print $obj->[0];

=cut

sub search_vendor_object($$$)
{
        my $this   = shift;
        my $vendor = shift;
        my $key    = shift;
        my $value  = shift;
        my @obj    = ();
        my $result1 = $this->{LDAP}->search(
                        base   => $this->{SCHOOL_BASE},
                        scope  => 'sub',
                        filter => "(o=$vendor)",
                        attrs  => []
                        );
        if( $result1->code )
        {
                return undef;
        }
        foreach my $j ( $result1->entries )
        {
                my $result = $this->{LDAP}->search(
                                base   => $j->dn,
                                scope  => 'one',
                                filter => "(&(objectclass=schoolConfiguration)(cKey=$key)(cValue=$value))",
                                attrs  => []
                                );
                foreach my $i ( $result->entries )
                {
                        push @obj, $i->dn;
                }
        }
        return \@obj;
}
#-----------------------------------------------------------------------
  
=item B<search_objects_for_vendor_object(vendor,key,value)>

Search the objects which contains vendor object with given vendor key and value;

EXAMPLE:

    $oss->search_objects_for_vendor_object( 'extis','rights','read');

    $oss->search_objects_for_vendor_object( 'extis','rights','*');

=cut

sub search_objects_for_vendor_object($$$)
{
	my $this   = shift;
	my $vendor = shift;
	my $key    = shift;
	my $value  = shift;
	my @obj    = ();
	my $result = $this->{LDAP}->search( 
			base   => $this->{SCHOOL_BASE}, 
			scope  => 'sub',
			filter => "(&(objectclass=schoolConfiguration)(cKey=$key)(cValue=$value))",
			);
	if( $result->code )
	{
		return undef;
	}
	foreach my $i ( $result->entries )
	{
		my $dn = $i->dn;
		if( $dn =~ s/^configurationKey=$key,o=$vendor,//i)
		{
			push @obj, $dn;
		}
	}
	return \@obj;
}
#-----------------------------------------------------------------------

=item B<modify_vendor_object(dn,vendor,key,value)>

Replace the values of the vendor object.

EXAMPLE:

    $oss->modify_vendor_object( 'uid=admin,ou=people,dc=EXTIS-School,dc=de',
				'extis','rights',['read','write']
    );

=cut

sub modify_vendor_object($$$$)
{
	my $this   = shift;
	my $dn     = shift;
	my $vendor = shift;
	my $key    = shift;
	my $value  = shift;
	my $vbase  = 'o='.$vendor.','.$dn;
	my $kbase  = 'configurationKey='.$key.','.$vbase;
	
	if( $this->exists_dn($dn) != 1)
	{
	  return undef;
	}
	if( $this->exists_dn($kbase) != 1)
	{
	  return undef;
	}
	my $entry = $this->get_entry($kbase,1);
	if( $entry->exists('configurationvalue') )
	{
		$entry->replace( configurationvalue => $value );
	}
	else
	{
		$entry->add( configurationvalue => $value );
	}
	$entry->update($this->{LDAP});
}

#-----------------------------------------------------------------------
=item B<get_group_dn(cn,[SchoolBase])>

Returns the dn of a group or undef if no or more then one group was found. 

EXAMPLE:

  my $dn = $oss->get_group_dn('10A');

  my $dn = $oss->get_group_dn('10A',dn_of_the_school);

=cut

sub get_group_dn
{
    my $this         = shift;
    my $group        = shift || return undef;
    my $school_base  = shift || '';
    my $pref = '';
    my $mesg;

    my $base	= $this->{SCHOOL_BASE};

    # First we have to search the school prefix;
    if( $school_base ne '' )
    {
      $pref = $this->get_school_config('SCHOOL_GROUP_PREFIX',$school_base);
      if( $group !~ /^$pref/ )
      {
        $group = $pref.$group;
      }
      $base = $school_base;
    }
    
    $mesg = $this->{LDAP}->search( base   => "ou=group,$base",
    			 scope  => 'one',
          		 filter => "(&(cn=$group)(objectClass=schoolGroup))",
          		 attrs  => ['dn' ]
          		);
    if( $mesg->code() || $mesg->count() != 1 )
    {
      return undef;
    }
    return $mesg->entry(0)->dn();
}
#-----------------------------------------------------------------------
=item B<get_user_dn(uid,dn)>

Returns the dn of an user or undef if no or more then one use was found. 

EXAMPLE:

  my $dn = $oss->get_user_dn(varkpete);

  my $dn = $oss->get_user_dn(varkpete,dn_of_the_school);

=cut

sub get_user_dn
{
    my $this         = shift;
    my $uid          = shift || return undef;
    my $school_base  = shift || $this->{SCHOOL_BASE};
    my $mesg;

    # First we have to search the school prefix;
    my $pref = $this->get_school_config('SCHOOL_LOGIN_PREFIX',$school_base);
    if( $pref && $uid !~ /^$pref/ )
    {
      $uid = $pref.$uid;
    }
    
    $mesg = $this->{LDAP}->search( base   => $school_base,
    			 	   scope  => 'sub',
          		           filter => "(&(uid=$uid)(objectClass=SchoolAccount))",
          		           attrs  => [ 'dn' ]
          		);
    if( $mesg->code() || $mesg->count() != 1 )
    {
      return undef;
    }
    return $mesg->entry(0)->dn();
}
#-----------------------------------------------------------------------

=item B<rc(service,what)

Subroutine to manipulate the system services

EXAMPLE

   if( ! $oss->rc("named","restart") )
   {
       print "Can not restart named: ".$oss->ERROR->{text};
   }

=cut

sub rc
{
    my $this         = shift;
    my $service      = shift;
    my $what         = shift;
    my $where        = shift || undef;

    if( ! -e "/etc/init.d/$service" )
    {
        $this->{ERROR}->{code} = "RC-ERROR";
	$this->{ERROR}->{text} = "Service: ".$service." do not exists.";
	return undef;
    }
    my $WHATS = `/etc/init.d/$service`;
    $WHATS =~ /.*{(.*)}/;
    $WHATS = $1;
    if( $what !~ /$WHATS/ )
    {
        $this->{ERROR}->{code} = "RC-ERROR";
	$this->{ERROR}->{text} = "Command: ".$what." is not implemented for service: ".$service;
	return undef;
    }
    if( $where )
    {
        system("ssh $where /etc/init.d/$service $what");
    }
    else
    {
        system("/etc/init.d/$service $what");
    }

}
#-----------------------------------------------------------------------
=item B<get_mail_domains([WithMainDomain])>

Subrotine to get the list of the mail domains. If WithMainDomain is given and
is true the main domain will be returned as default

=cut

sub get_mail_domains()
{
    my $this         = shift;
    my $default      = shift || 0;
    my @domains      = ();

    my $mess = $this->{LDAP}->search( base => $this->{SYSCONFIG}->{DNS_BASE},
				      filter => '(objectclass=suseMailDomain)',
				      attrs  => ['zoneName']
				);
   foreach my $e ( $mess->entries )
   {
   	push @domains, $e->get_value('zoneName');
   }
   if( $default )
   {
       $mess = $this->{LDAP}->search( base => $this->{SYSCONFIG}->{DNS_BASE},
				      filter => '(&(objectclass=suseMailDomain)(suseMailDomainType=main))',
				      attrs  => ['zoneName']
				);
	push @domains, '---DEFAULTS---',$mess->entry(0)->get_value('zoneName');
   }
   return \@domains;
}
#-----------------------------------------------------------------------
=item B<get_printers>

Subroutine to get the configuration of the printer in a form of a hash.

=cut

sub get_printers
{
	my $this        = shift;
	my $ret         = "";
	if( $this->{PRINTSERVER_LOCAL} )
	{
		$ret = `cat /etc/cups/printers.conf`;
	}
	else
	{
		$ret = `ssh printserver cat /etc/cups/printers.conf`;
	}
	
	
	my $printer     ="";
	my %PRINTERS    =();
	
	foreach (split /\n/, $ret) {
		# Comment
		next if( /^#/ );
		# Default Printer
		if( /<DefaultPrinter\s+(.*)>/ ) {
			$printer = $1;
			$PRINTERS{DEFAULT} = $1;
			$PRINTERS{$1}->{NRJ} = 0;
			next;
		}
		# Printer
		if( /<Printer (.*)>/ ) {
			$printer = $1;
			$PRINTERS{$1}->{NRJ} = 0;
		}
		# End of Printer Section
		next if( /<\/Printer>/ );
		if( /^(\w+)\s+(.*)$/) {
			if( defined $PRINTERS{$printer}->{$1} ) {
				$PRINTERS{$printer}->{$1} .= ','.$2;
			} else {
				$PRINTERS{$printer}->{$1} = $2;
			}
		}
	}
	if( $this->{PRINTSERVER_LOCAL} )
	{
	        $ret = `lpstat -o`;
	}
	else
	{
	        $ret = `ssh printserver 'lpstat -o'`;
	}
	foreach my $i (split /\n/, $ret) {
	        my @line = (split /\s+/,$i);
	        $line[0] =~ /(.*)-(\d+)/;
		$PRINTERS{$1}->{NRJ}++ if( $1 );
	}
	return \%PRINTERS;
}

=item B<$oss->add_dns_record((zone, relativedomainname, class, type, value)>

EXAMPLE :
	(  $this->add_dns_record( "$zone", "$relativedomainname", "$class", "$type", "$aRecord");  )
	$oss->add_dns_record( 'EXTIS-School.org', 'admin', 'IN', 'aRecord', '172.16.0.2')
	$this->add_dns_record( "$zone", "$relativedomainname", "$class", "$type", "$aRecord");
=cut

sub add_dns_record
{
	my $this     = shift;
	my $Zone     = shift;
	my $RelativeDomainName = shift;
	my $dNSClass     = shift;
	my $Record_Type  = shift;
	my $Record_Value = shift;  
	my $recordDN     = "";

	my $mesg = $this->{LDAP}->search( base    => $this->{SYSCONFIG}->{DNS_BASE},
	                                  scope   => 'sub',
	                                  attrs   => ['dn'],
	                                  filter  => "(&(relativeDomainName=@)(zoneName=$Zone))"
		);
	if( $mesg->code)
	{
		$this->ldap_error($mesg);
		return undef;
	}
	my $base = $mesg->entry(0)->dn;

	$recordDN= 'relativeDomainName='.$RelativeDomainName.','.$base;
	$mesg = $this->{LDAP}->search(    base    => $base,
                                          scope   => 'one',
                                          attrs   => ["$Record_Type"],
                                          filter  => 'relativeDomainName='.$RelativeDomainName
                                     );
	if( $mesg->code ){
		$this->ldap_error($mesg);
		return undef;
	}elsif( $mesg->count == 0 ){
	  # The entry does not exist yet a new on has to be created
		my $hostentry = Net::LDAP::Entry->new();
		$hostentry->dn( $recordDN );
		$hostentry->add(  "$Record_Type"          => $Record_Value,
				  dNSClass		  => $dNSClass,
				  dNSTTL                  => '604800',
				  objectClass             => ['dNSZone'],
	                          relativeDomainName      => $RelativeDomainName,
	                          zoneName                => $Zone,
	                     );
	        $mesg = $this->{LDAP}->add($hostentry);
	        if($mesg->code){
	        	$this->ldap_error($mesg);
	        	return undef;
	        }
	}else{
#		$mesg = $this->{LDAP}->modify( $recordDN, "add" => { "$Record_Type" => "$Record_Value"});
#		if($mesg->code){
#			$this->ldap_error($mesg);
#			return undef;
#		}
		return undef;
	}
	$this->update_soa($Zone);
        return $recordDN;
}

=item B<$oss->get_logged_users("$room_dn")>

EXAMPLE :  $oss->get_logged_users("$room_dn");

=cut

sub get_logged_users
{
	my $this    = shift;
	my $room_dn = shift;
	my %hash;

	foreach my $dn (sort @{$this->get_workstations_of_room($room_dn)} )
	{
		$hash{$dn}->{host_name} = $this->get_attribute($dn,'cn');
		my @ws = $this->get_attribute($dn,'configurationValue');
		foreach my $conf_value (@ws){
			if( $conf_value =~ /^LOGGED_ON=(.*)$/){
				$hash{$dn}->{user_name} = $1;
				$hash{$dn}->{user_cn} = $this->get_attribute($this->get_user_dn("$1"), 'cn');
			}
		}
	}

	return \%hash;
}

1;
