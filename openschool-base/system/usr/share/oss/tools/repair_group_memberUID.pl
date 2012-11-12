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
	print   'Usage: /usr/share/oss/tools/repair_group_memberUID.pl [OPTION]'."\n".
		'Add missed memberUid attributes to a group'."\n\n".
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
		'	repair_group_memberUID.pl'."\n".
		'DESCRIPTION:'."\n".
		'	Add missed memberUid attributes to a group'."\n".
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
                        filter  => '(objectClass=schoolGroup)',
                        attrs   => ['member','memberUID']
                     );

foreach my $entry ( $mess->entries ) {
    my @memberUIDs = $entry->get_value('memberUID');
    foreach my $member ( $entry->get_value('member') )
    {
	next if( $oss->is_template($member) );
	my $memberUID = get_name_of_dn($member); 
        next if( $memberUID eq 'admin' );
	if( ! contains($memberUID,\@memberUIDs) )
	{
	    $oss->{LDAP}->modify( $entry->dn(), add=> { memberUID => $memberUID } );
	    print "Add $memberUID to ".$entry->dn()." as memberUID\n";
	}
    }
}

