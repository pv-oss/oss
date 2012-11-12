=head1 NAME
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

 oss_LDAPAttributes

=head1 PREFACE

 This package contains utilities to manage the ldap-attributes of the openschoolserver.

=head1 SYNOPSIS

=over 2

=cut


BEGIN{ 
  push @INC,"/usr/share/oss/lib/";
}

require Exporter;
package oss_LDAPAttributes;
use strict;
use oss_utils;

use vars qw(    @ISA
		@EXPORT
		@additionalUserAttributes
		@defaultUserAttributes
		@defaultGroupAttributes
		@requiredUserAttributes
		@requiredGroupAttributes
		@userAttributes
		@userAttributeList
		@groupAttributes
		@userAttributesToInherit
		@groupAttributesToInherit
		@mailEnabledChange
		@mailEnabled
		@disabledChange
		@enabledChange
		@disabledChangeYesLabel
		@disabledChangeNoLabel
		%disabledLabel
		%enabledLabel
		%defaultUser
		%defaultGroup
		%defaultMachineAccount
		);

@ISA = qw(Exporter);

@EXPORT = qw(
		&check_user_ldap_attributes
		&is_user_ldap_attribute
		&check_group_ldap_attributes
		&is_group_ldap_attribute
		&check_email_address
		@additionalUserAttributes
		@defaultUserAttributes
		@defaultGroupAttributes
		@requiredUserAttributes
		@requiredGroupAttributes
		@userAttributes
		@userAttributeList
		@groupAttributes
		@userAttributesToInherit
		@groupAttributesToInherit
		@mailEnabledChange
		@mailEnabled
		@disabledChange
		@enabledChange
		@disabledChangeYesLabel
		@disabledChangeNoLabel
		%disabledLabel
		%enabledLabel
		%defaultUser
		%defaultGroup
		%defaultMachineAccount
	);

=item B<@requiredUserAttributes>

Array containing the minimal set of user attributes.

=cut

@requiredUserAttributes = qw (
sn
role
userpassword
);

=item B<@requiredGroupAttributes>

Array containing the minimal set of group attributes.

=cut

@requiredGroupAttributes = qw (
cn
grouptype
);

=item B<@userAttributesToInherit>

Array containing the list of user attributes which will be inherit from the template user.

=cut

@userAttributesToInherit = qw (
objectclass
ipphone
oxappointmentdays
oxdayviewendtime
oxdayviewinterval
oxdayviewstarttime
oxenabled
oxgroupid
oxgroupwarestyle
oxtaskdays
oxtimezone
oxuseranniversary
oxuserassistant
oxuserbranches
oxusercategories
oxuserchildren
oxusercity
oxusercomreg
oxusercomment
oxuserdistributionlist
oxuseremail2
oxuseremail3
oxuserinstantmessenger
oxuserinstantmessenger2
oxusermaritalstatus
oxusernickname
oxuserothercity
oxuserothercountry
oxuserotherpostalcode
oxuserotherstate
oxuserotherstreet
oxuserposition
oxuserpostalcode
oxuserprofession
oxusersalesvolume
oxuserspousename
oxuserstate
oxusersuffix
oxusertaxid
oxuserteleassistant
oxusertelebusiness2
oxusertelecallback
oxusertelecar
oxusertelecompany
oxusertelefax2
oxusertelehome2
oxusertelemobile2
oxuserteleother
oxuserteleprimary
oxuserteleradio
oxuserteletty
oxwebmailstyle
audio
businesscategory
c
carlicense
co
colocrouteaddr
conferenceinformation
configurationvalue
defaultuseraci
departmentnumber
destinationindicator
displayname
employeenumber
employeetype
gecos
gidnumber
groupwareserver
groupwareserverport
imapport
imapserver
importsortindirectory
info
initials
internationalisdnnumber
internetdisabled
jpegphoto
l
labeleduri
lnetmailaccess
logindestination
logindisabled
loginshell
mail
maildomain
mailenabled
manager
middlename
o
otherpager
ou
oxjdbcdatabaseurl
oxjdbcdriverclassname
oxjdbclogin
oxjdbcpassword
pager
photo
physicaldeliveryofficename
postofficebox
preferreddeliverymethod
preferredlanguage
rasaccess
registeredaddress
reject
relclientcert
religion
roomnumber
sambaacctflags
sambabadpasswordcount
sambabadpasswordtime
sambahomedrive
sambahomepath
sambakickofftime
sambalmpassword
sambalogofftime
sambalogonhours
sambalogonscript
sambalogontime
sambamungeddial
sambantpassword
sambapasswordhistory
sambaprimarygroupsid
sambaprofilepath
sambauserworkstations
secretary
seealso
shadowexpire
shadowflag
shadowinactive
shadowmax
shadowmin
shadowwarning
sieveport
smtpport
smtpserver
sn
susedeliverytofolder
st
street
title
url
userpassword
usercountry
webmailserver
webmailserverport
writerdn
zarafaQuotaOverride
zarafaQuotaWarn
zarafaQuotaSoft
zarafaSendAsPrivilege
zarafaQuotaHard
zarafaAdmin
zarafaSharedStoreOnly
zarafaResourceType
zarafaResourceCapacity
zarafaAccount
zarafaHidden
zarafaAliases
zarafaUserServer
zarafaEnabledFeatures
zarafaDisabledFeatures
);

=item B<@userAttributes>

Array containing the list of all user LDAP-attributes.

=cut

@userAttributes = qw (
objectclass
ipphone
oxappointmentdays
oxdayviewendtime
oxdayviewinterval
oxdayviewstarttime
oxenabled
oxgroupid
oxgroupwarestyle
oxtaskdays
oxtimezone
oxuseranniversary
oxuserassistant
oxuserbranches
oxusercategories
oxuserchildren
oxusercity
oxusercomreg
oxusercomment
oxuserdistributionlist
oxuseremail2
oxuseremail3
oxuserinstantmessenger
oxuserinstantmessenger2
oxusermaritalstatus
oxusernickname
oxuserothercity
oxuserothercountry
oxuserotherpostalcode
oxuserotherstate
oxuserotherstreet
oxuserposition
oxuserpostalcode
oxuserprofession
oxusersalesvolume
oxuserspousename
oxuserstate
oxusersuffix
oxusertaxid
oxuserteleassistant
oxusertelebusiness2
oxusertelecallback
oxusertelecar
oxusertelecompany
oxusertelefax2
oxusertelehome2
oxusertelemobile2
oxuserteleother
oxuserteleprimary
oxuserteleradio
oxuserteletty
oxwebmailstyle
addressbookcn
audio
authdata
birthday
businesscategory
c
carlicense
cn
co
colocrouteaddr
conferenceinformation
configurationvalue
defaultuseraci
departmentnumber
description
destinationindicator
displayname
employeenumber
employeetype
facsimiletelephonenumber
gecos
gidnumber
givenname
groupwareserver
groupwareserverport
homedirectory
homephone
homepostaladdress
imapport
imapserver
importsortindirectory
info
initials
internationalisdnnumber
internetdisabled
jpegphoto
l
labeleduri
lnetmailaccess
logindestination
logindisabled
loginshell
mail
maildomain
mailenabled
manager
middlename
mobile
o
otherfacsimiletelephonenumber
otherpager
ou
oxjdbcdatabaseurl
oxjdbcdriverclassname
oxjdbclogin
oxjdbcpassword
pager
photo
physicaldeliveryofficename
postofficebox
postaladdress
postalcode
preferreddeliverymethod
preferredlanguage
rasaccess
registeredaddress
reject
relclientcert
religion
role
roomnumber
sambaacctflags
sambabadpasswordcount
sambabadpasswordtime
sambadomainname
sambahomedrive
sambahomepath
sambakickofftime
sambalmpassword
sambalogofftime
sambalogonhours
sambalogonscript
sambalogontime
sambamungeddial
sambantpassword
sambapasswordhistory
sambaprimarygroupsid
sambaprofilepath
sambapwdcanchange
sambapwdlastset
sambapwdmustchange
sambasid
sambauserworkstations
secretary
seealso
shadowexpire
shadowflag
shadowinactive
shadowlastchange
shadowmax
shadowmin
shadowwarning
sieveport
smtpport
smtpserver
sn
st
street
susedeliverytofolder
susemailacceptaddress
susemailforwardaddress
telephonenumber
teletexterminalidentifier
telexnumber
title
uid
uidnumber
uniqueidentifier
url
usercertificate
usercountry
userpkcs12
userpassword
usersmimecertificate
vaddress
webmailserver
webmailserverport
writerdn
x121address
x500uniqueidentifier
zarafaQuotaOverride
zarafaQuotaWarn
zarafaQuotaSoft
zarafaSendAsPrivilege
zarafaQuotaHard
zarafaAdmin
zarafaSharedStoreOnly
zarafaResourceType
zarafaResourceCapacity
zarafaAccount
zarafaHidden
zarafaAliases
zarafaUserServer
zarafaEnabledFeatures
zarafaDisabledFeatures
);

=item B<@defaultUserAttributes>

Array containing the list of the default user LDAP-attributes.
These attributes will be returned be searching user without determining the wanted
attributes. Please remeber, that quota & fquota are very expensive to determine.

=cut

@defaultUserAttributes = qw (
admin
c
cn
facsimiletelephonenumber
fquota
gidnumber
givenname
group
homephone
l
labeleduri
mail
mobile
ou
oxtimezone
postalcode
preferredlanguage
quota
role
sn
st
street
susemailacceptaddress
susemailforwardaddress
telephonenumber
title
uid
uidnumber
);

=item B<@userAttributeList>

Array containing the list of the user LDAP-attributes for editUser.

=cut

@userAttributeList = qw (
uid
title
sn
givenname
description
admin
quota
quotaused
fquota
fquotaused
group
mail
ou
susemailacceptaddress
susemailforwardaddress
susedeliverytofolder
preferredlanguage
oxtimezone
telephonenumber
mailenabled
mobile
homephone
c
l
postalcode
st
street
rasaccess
);

=item B<@additionlaUserAttributes>

This are attributes user may contain but this attributes are not LDAP attributes.

=cut

@additionalUserAttributes = qw (
class
group
admin
quota
fquota
mbox
);

=item B<%defaultUser>

Hash containing the user attributes of the default user. If no template user was given
or no template user can determine the defaultUser will be used as template.

=cut

%defaultUser =
(
	objectclass	    => ['top','shadowAccount','posixAccount','person','inetOrgPerson','SchoolAccount','OXUserObject','phpgwAccount','suseMailRecipient','sambaSamAccount'],
	c                   => ['DE'],
	givenname	    => ['System'],
	homedirectory	    => ['/etc/skel'],
	internetdisabled    => ['no'],
	imapserver	    => ['mailserver'],
	logindisabled	    => ['no'],
	loginshell	    => ['/bin/bash'],
	mbox                => ['Sent','Trash','Spam','Templates'],
	mailenabled	    => ['ok'],
	oxenabled	    => ['ok'],
	oxappointmentdays   => ['5'],
	oxtaskdays          => ['5'],
	oxdayviewendtime    => ['16:00'],
  	oxdayviewinterval   => ['10'],
	oxdayviewstarttime  => ['07:30'],
	oxtimezone          => ['Europe/Berlin'],
	preferredlanguage   => ['DE'],
	susedeliverytofolder=> ['1'],
	phpgwaccounttype    => ['u'],
	phpgwaccountstatus  => ['A'],
	phpgwaccountexpires => ['-1'],
	smtpserver	    => ['mailserver'],
	sn		    => ['Administrator'],
	uid                 => ['admin'],
	usercountry         => ['DE']
);


@groupAttributes = qw
(
businesscategory
cn
description
displayname
gidnumber
grouptype
member
memberuid
o
objectclass
ou
owner
phpgwaccountexpires
phpgwaccountlastlogin
phpgwaccountlastloginfrom
phpgwaccountstatus
phpgwaccounttype
phpgwlastpasswdchange
role
sambagrouptype
sambasid
sambasidlist
seealso
susedeliverytofolder
susedeliverytomember
susemailacceptaddress
susemailcommand
susemailforwardaddress
writerdn
);

@defaultGroupAttributes = qw (
cn
description
quota
quotaused
fquota
fquotaused
susedeliverytofolder
susedeliverytomember
susemailacceptaddress
susemailforwardaddress
member
);

@groupAttributesToInherit = qw (
objectclass
phpgwaccounttype
phpgwaccountstatus
phpgwaccountexpires
susedeliverytofolder
susedeliverytomember
userpassword
grouptype
quota
fquota
web
writerdn
);

%defaultGroup =
(
	objectclass	    => ['top' ,'posixGroup' ,'schoolGroup' ,'phpgwAccount' ,'sambaGroupMapping' ,'groupOfNames' ],
	phpgwaccounttype    => ['g'],
	phpgwaccountstatus  => ['A'],
	phpgwaccountexpires => ['-1'],
	userpassword        => ['*'],
	grouptype	    => ['workgroup'],
	susedeliverytomember=> [0],
	susedeliverytofolder=> [1],
	quota		    => [0],
	fquota		    => [0],
	web		    => [0]
);

%defaultMachineAccount =
(
	description	    =>  ['Workstation test ip:172.16.2.2'],
	uid		    =>  ['test$'],
	uidnumber	    =>  ['1000002'],
	userpassword        =>  ['{crypt}*'],
	loginshell	    =>  ['/bin/false'],
	gidnumber	    =>  ['65534'],
	homedirectory	    =>  ['/dev/null'],
	cn		    =>  ['test$'],
	sn		    =>  ['Machine'],
	shadowinactive	    =>  ['-1'],
	shadowlastchange    =>  ['12752'],
	shadowmax	    =>  ['99999'],
	shadowmin	    =>  ['0'],
	shadowwarning	    =>  ['7'],
	sambaacctflags	    =>  ['[W          ]'],
	sambalmpassword     =>  ['0182BD0BD4444BF836077A718CCDF409'],
	sambantpassword     =>  ['259745CB123A52AA2E693AAACCA2DB52'],
	sambaprimarygroupsid=>  ['nix'],
	sambasid	    =>  ['nix'],
	objectclass	    =>  [ 'top' , 'posixAccount' , 'shadowAccount' , 'inetOrgPerson' , 'sambaSamAccount' ]

);

@mailEnabledChange = ( 'do_not_change', 'ok', 'local_only','NO', '---DEFAULTS---' , 'do_not_change');
@mailEnabled	   = ( 'ok', 'local_only','NO', '---DEFAULTS---' , 'ok');
@disabledChangeYesLabel = ( 'yes', 'disabled' );
@disabledChangeNoLabel  = ( 'no', 'enabled' );
@disabledChange    = ( 'do_not_change', \@disabledChangeNoLabel, \@disabledChangeYesLabel , '---DEFAULTS---' , 'do_not_change' );
@enabledChange     = ( 'do_not_change', [ 'ok', 'enabled' ],   [ 'no','disabled'], '---DEFAULTS---' , 'do_not_change' );
%disabledLabel     = ( yes => 'disabled', 'no' => 'enabled' );
%enabledLabel      = ( no  => 'disabled', 'ok' => 'enabled' );

=item B<check_user_ldap_attributes(userhash)>

check if all required attriutes are given and if they are OK

Enample:

  Checks the attributes and displays the error.
  print check_user_ldap_attributes($user);

  Checks the attributes and displays the error and remove attributes with bad syntax
  print check_user_ldap_attributes($user,'remove');

  Checks the attributes and displays the error and correct attributes with bad syntax
  print check_user_ldap_attributes($user,'correct');

=cut

sub check_user_ldap_attributes
{
    my $user    = shift;
    my $correct = shift || 0 ;
    my $plength = parse_file("/etc/sysconfig/schoolserver", "SCHOOL_MINIMAL_PASSWORD_LENGTH=") || 6 ;
    my $error= '';
    my @attrs=@requiredUserAttributes;

    if( $user->{role} =~ /teachers|students/ && $user->{role} !~ /,templates/ )
    {
    	push @attrs, ( 'givenname','birthday');
    }

    foreach my $attr (@attrs)
    {
    	if( ! $user->{$attr} )
	{
	    $error .= "required attribute '$attr' is not defined<br>";
	}
    }
#TODO make syntax checks
    foreach(keys %$user)
    {
	next if( !defined $user->{$_} );
	if( $user->{$_} && /^uid$/i ){
		if( $user->{$_} !~ /^[a-zA-Z0-9][\.\$\-a-zA-Z0-9_]{0,30}[a-zA-Z0-9\$]$/ ){
			$error .= 'uid: '.$user->{$_}.'<br>';
			$error .= "Please don\'t use special characters when entering the $_ ( ex. special charakter: á, ú, ű, é, ß, ä ).<br>";
		}
	}
	if( /^userpassword$/ ){
		if( length($user->{$_}) < $plength ){
			$error .= "The user password is at least $plength characters long.<br>";
		}
	}
    	if( /^mobile$|^homePhone$|TelephoneNumber$/i )
	{
		if( $user->{$_} eq '' )
		{
			delete $user->{$_};
			next;
		}
		if( $user->{$_} =~ /[^a-zA-Z0-9-+.()\/ ]+/ )
		{
			if( ! $correct )
			{
				$error .= "Attribute $_ has value in bad syntax: '".$user->{$_}."' During import this Problem will be corrected.\n";
			}
			elsif( $correct eq 'correct' )
			{
				$user->{$_} =~ s/[^a-zA-Z0-9-+.()\/ ]/ /g;
			}
			else
			{
				delete $user->{$_};
			}
		}
	}
	if( /^newsusemailacceptaddress$|^newsusemailforwardaddress$/ ){
		foreach my $i ( @{$user->{$_}} )
		{
			if( !check_email_address($i) ){
				$error .= "'$i' is an invalid email address.\n";
			}
		}
	}
    }
    return $error;
}

=item B<is_user_ldap_attribute(name)>

check if the string an user ldap attribute is.

Enample:

  print "cn is a ldap attribut" if( is_user_ldap_attribute(cn)) ;

=cut

sub is_user_ldap_attribute($)
{
    my $attr = shift;
    return contains($attr,\@userAttributes);
}

=item B<check_group_ldap_attributes(grouphash)>

check if all required attriutes are given and if

Enample:

  print "cn is a ldap attribut" if( is_group_ldap_attribute(cn)) ;

=cut

sub check_group_ldap_attributes($)
{
    my $group = shift;
    my $error= '';
    foreach my $attr (@requiredGroupAttributes)
    {
    	if( !defined  $group->{$attr} )
	{
	    $error .= "required attribute '$attr' is not defined";
	}
    }
    if( $group->{grouptype} eq 'primary' && !defined $group->{role} )
    {
        $group->{role} = lc($group->{cn});
    }
    if( length $group->{cn} < 2 )
    {
    	return "Group name must conain at last 2 characters";
    }
    if( $group->{cn} =~ / |\t/ )
    {
    	return "Group name must not contains white spaces!";
    }
    if( $group->{cn} !~ /^[a-zA-Z0-9][a-zA-Z0-9_\.\-]{0,28}[a-zA-Z0-9]$/ ){
	$error .= "Invalid group name: ".$group->{cn}."\n";
	$error .= "Please don\'t use special characters when entering the GroupName  ( ex. special charakter: á, ú, ű, é, ß, ä ).";
    	return $error;
    }
    return $error;
}

=item B<is_group_ldap_attribute(name)>

check if the string an group ldap attribute is.

Enample:

  print "cn is a ldap attribut" if( is_group_ldap_attribute(cn)) ;

=cut

sub is_group_ldap_attribute($)
{
    my $attr = shift;
    return contains($attr,\@groupAttributes);
}

=item B<check_email_address(email_address)>

check email address.

Enample:

  print "example@extis.de is valid" if( check_email_address("example@extis.de")) ;

=cut

sub check_email_address
{
    my $email_address = shift;
    if ($email_address =~ /^(\w|\-|\_|\.)+\@((\w|\-|\_)+\.)+[a-zA-Z]{2,}$/)
    {
	return 1
    }
    else
    {
	return undef;
    }
}

1;
