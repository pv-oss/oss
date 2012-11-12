#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_base;
use oss_utils;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/add_users_to_moodle.pl [OPTION]'."\n".
		'With this script we can add the users on the OSS server to the moodle.'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		"	No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'Optional parameters : '."\n".
		'	-h, --help         Display this help.'."\n".
		'	-d, --description  Display the descriptiont.'."\n";
}
if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'       add_users_to_moodle.pl'."\n".
		'DESCRIPTION:'."\n".
		'	With this script we can add the users on the OSS server to the moodle.'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"		          : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h, --help        : Display this help.(type=boolean)'."\n".
		'		-d, --description : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}

my @attrs = qw( uidnumber uid givenname sn mail o ou c preferredlanguage description role );
my $oss = oss_base->new();

my $result = $oss->{LDAP}->search( base => $oss->{SYSCONFIG}->{USER_BASE},
                                   scope=> 'one',
                                   filter=> '(|(role=students)(role=teachers*))',
                                   );
foreach my $e ( $result->entries() )
{
        my $attrs = '';
        foreach my $a ( @attrs )
        {
                $attrs .= "$a ".$e->get_value($a)."\n";
        }
	print $e->get_value('uid')."\n";
        cmd_pipe("/usr/share/oss/plugins/add_user/moodle-add-user",$attrs);
}
