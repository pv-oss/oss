#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use Net::LDAP;
use oss_base;
use oss_utils;
# Make LDAP Connection
my $oss = oss_base->new();

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
			"date=s",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/find_created_user.pl [OPTION]'."\n".
		'Script to search user created on a date.'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		"	No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'Optional parameters: '."\n".
		'	-h,  --help            Display this help.'."\n".
		'	     --description     Display the descriptiont.'."\n".
		'	     --date            Date. YYYY[MM[DD]]'."\n";
}

if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	find_created_user.pl'."\n".
		'DESCRIPTION:'."\n".
		'	Script to search user created on a date.'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"		                    : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h,  --help         : Display this help.(type=boolean)'."\n".
		'		-d,  --description  : Display the descriptiont.(type=boolean)'."\n";
		'                    --date         : Date. YYYY[MM[DD]](type=string)'."\n".
	exit 0;
}
my $date = undef;
if( defined($options{'date'}) ){
	$date = $options{'date'};
}

my $mess = $oss->{LDAP}->search(
                        base    => 'ou=people,'.$oss->{LDAP_BASE},
                        scope   => 'one',
                        filter  => '(objectclass=schoolAccount)',
                        attrs   => ['createTimestamp','uid','cn','birthday','ou']
                     );


foreach my $entry ( $mess->entries ) {
        my $uid      = $entry->get_value('uid');
        my $created  = $entry->get_value('createTimestamp');
	my $password = '';
	if( $created =~ /^$date/ )
	{
               for( my $i=0; $i < 8; $i++)
               {
                 $password .= pack( "C", int(rand(25)+97) );
               }

	        print $entry->get_value('ou').":".$entry->get_value('cn').":".$entry->get_value('birthday').":$uid:$password\n\n";
		# uncomment the next line if you want to set this ne password
		#$oss->set_password($entry->dn,$password,0,0,'SMD5');

	}
}

