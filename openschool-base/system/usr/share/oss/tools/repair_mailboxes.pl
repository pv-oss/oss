#!/usr/bin/perl  -w
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_base;
use oss_utils;
use Net::IMAP;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/repair_mailboxes.pl [OPTION]'."\n".
		'This script recreates all mail boxes'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		"	No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'Optional parameters: '."\n".
		'	-h, --help         Display this help.'."\n".
		'	-d, --description  Display the descriptiont.'."\n";
}
if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	repair_mailboxes.pl'."\n".
		'DESCRIPTION:'."\n".
		'	Leiras ...'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"		                  : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h, --help        : Display this help.(type=boolean)'."\n".
		'		-d, --description : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}

my $mess    = undef;
my $resp    = undef;
my $errs    = undef;

my $oss     = oss_base->new({withIMAP => 1});

$mess = $oss->{LDAP}->search(
                        base    => $oss->{SYSCONFIG}->{GROUP_BASE},
                        scope   => 'one',
                        filter  => '(groupType=class)',
                        attrs   => ['cn','objectClass']
                     );

foreach my $entry ( $mess->entries ) {
    my $cn       = $entry->get_value('cn');
print $cn."\n";
    $oss->{IMAP}->create($cn);
    $oss->{IMAP}->setacl($cn,'cyrus','lrswipkxtea');
    $oss->{IMAP}->setacl($cn,"group:$cn",'lrs');
}

$mess = $oss->{LDAP}->search(
                        base    => $oss->{SYSCONFIG}->{GROUP_BASE},
                        scope   => 'one',
                        filter  => '(&(!(groupType=class))(objectclass=suseMailRecipient))',
                        attrs   => ['cn','objectClass']
                     );

foreach my $entry ( $mess->entries ) {
    my $cn       = $entry->get_value('cn');
    print $cn."\n";
    $oss->{IMAP}->create($cn);
    $oss->{IMAP}->setacl($cn,'cyrus','lrswipkxtea');
    $resp = $oss->{IMAP}->setacl($cn,"group:$cn",'lrswipkxtea');
    if($$resp{Status} ne "ok") {
      $errs .= "IMAP setacl failed for $cn:  Serverresponse: $$resp{Status} => $$resp{Text}\n";
    }
}

$mess = $oss->{LDAP}->search(
                        base    => $oss->{SYSCONFIG}->{USER_BASE},
                        scope   => 'one',
                        filter  => '(objectclass=suseMailRecipient)',
                        attrs   => ['uid','role']
                     );


foreach my $entry ( $mess->entries ) {
    my $uid       = $entry->get_value('uid');
    my $role      = $entry->get_value('role');
    print $uid."\n";
    my $mbox      = "user/".$uid;
    $oss->{IMAP}->create($mbox);
    $oss->{IMAP}->setacl($mbox,'cyrus','lrswipkxtea');
    $oss->{IMAP}->setacl($mbox,$uid,'lrswipkxtea');
    $oss->{IMAP}->deleteacl($mbox,"anyone");
    $oss->{IMAP}->create($mbox."/Gesendet");
    $oss->{IMAP}->create($mbox."/Papierkorb");
    $oss->{IMAP}->create($mbox."/SPAM");
    $oss->{IMAP}->create($mbox."/Vorlagen");
    if ( $role =~ /teachers|sysadmins|administrators/ ) {
        my $class_entries =  $oss->{LDAP}->search(
                        base    => $oss->{SYSCONFIG}->{GROUP_BASE},
                        scope   => 'one',
                        filter  => "(&(groupType=class)(memberUid=$uid))",
                        attrs   => ['cn']
                     );
        foreach my $class_entry ($class_entries->entries){
            $resp  = $oss->{IMAP}->setacl($class_entry->get_value('cn'),$uid,"lrswipxte");
            if($$resp{Status} ne "ok") {
              $errs .= "IMAP setacl failed for $uid:  Serverresponse: $$resp{Status} => $$resp{Text}\n";
            }
        }
    }
}
foreach ( glob "/var/spool/imap/user/*" )
{
    s#/var/spool/imap/user/##;
    $mess = $oss->{LDAP}->search(
                        base    => $oss->{SYSCONFIG}->{USER_BASE},
                        scope   => 'one',
                        filter  => "(&(uid=$_)(objectclass=suseMailRecipient))",
                        attrs   => ['uid','role']
                     );
    if( ! $mess->count )
    {
        print "to delete $_\n";
        $resp  = $oss->{IMAP}->delete("user/$_");
        if($$resp{Status} ne "ok") {
          $errs .= "IMAP delete failed for user/$_:  Serverresponse: $$resp{Status} => $$resp{Text}\n";
        }
    }
}

print STDERR $errs if ( $errs );
