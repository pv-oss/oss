#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_base;
use oss_utils;
use Cyrus::IMAP::Admin;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/subscribe_all_mboxes.pl [OPTION]'."\n".
		'Tool to subscribe all mailboxes for all user.'."\n\n".
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
		'	subscribe_all_mboxes.pl'."\n".
		'DESCRIPTION:'."\n".
		'	Tool to subscribe all mailboxes for all user.'."\n".
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
                        base    => $oss->{SYSCONFIG}->{USER_BASE},
                        scope   => 'one',
                        filter  => '(objectclass=suseMailRecipient)',
                        attrs   => ['uid','userpassword']
                     );
foreach my $entry ( $mess->entries ) {
	my $uid       = $entry->get_value('uid');
	my $pw        = $entry->get_value('userpassword');
	my @box	      = ();
	print $uid."\n";
	my $imap = Cyrus::IMAP::Admin->new($oss->{SYSCONFIG}->{SCHOOL_MAILSERVER});
	#set the password temporaly
	$oss->{LDAP}->modify( $entry->dn , replace => { userpassword => '12345' });
	$imap->authenticate( -user => $uid,  -password => '12345', -mechanism => 'LOGIN'  );
	$oss->{LDAP}->modify( $entry->dn , replace => { userpassword => $pw });
	my @mailboxes = $imap->list('*');
	foreach my $i ( @mailboxes )
	{
		next if ( $i->[0] =~ /spam$/ );
		$imap->subscribe($i->[0]);
	}
}
	
