#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN
{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_base;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
                );
sub usage
{
	print   'Usage: /usr/share/oss/tools/put_all_in_domainusers.pl [OPTION]'."\n".
		'This script puts each and every user into the DOMAINUSERS group.'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		"	No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'Optional parameters : '."\n".
		'	-h,  --help          Display this help.'."\n".
		'	-d,  --description   Display the descriptiont.'."\n";
}

if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) )
{
	print   'NAME:'."\n".
		'	put_all_in_domainusers.pl'."\n".
		'DESCRIPTION:'."\n".
		'	This script puts each and every user into the DOMAINUSERS group.'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"		                     : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h,  --help          : Display this help.(type=boolean)'."\n".
		'		-d,  --description   : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}

my $oss = oss_base->new();

my $domu = $oss->get_group_dn('DOMAINUSERS');
my $mesg = $oss->{LDAP}->search( base   => $oss->{SYSCONFIG}->{USER_BASE},
                                  scope  => 'one',
                                  filter => "(!(memberOf=$domu))",
                                  attrs  => [ 'dn' ]
                                );

foreach my $e ( $mesg->entries )
{
	$oss->add_user_to_group($e->dn,$domu);
	print $e->dn."\n";
}
