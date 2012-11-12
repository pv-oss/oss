#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use Net::LDAP;
use oss_base;
use oss_utils;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
			"access=s"
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/repair_sym_links.pl [OPTION]'."\n".
		'With this script we can repair sym links for the students home directory for teachers access.'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		'	    --access       Correct value "yes".'."\n".
		'Optional parameters: '."\n".
		'	-h, --help         Display this help.'."\n".
		'	-d, --description  Display the descriptiont.'."\n";
}
if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	repair_sym_links.pl'."\n".
		'DESCRIPTION:'."\n".
		'	With this script we can repair sym links for the students home directory for teachers access.'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		'		    --access      : Correct value "yes".(type=string)'."\n".
		'	OPTIONAL:'."\n".
		'		-h, --help        : Display this help.(type=boolean)'."\n".
		'		-d, --description : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}

if ( defined($options{'access'}) ){
	if( $options{'access'} ne 'yes'){
		usage();exit;
	}
}else{
	usage();exit;
}

# Make LDAP Connection
my $oss = oss_base->new();

my $mess = $oss->{LDAP}->search(
                        base    => 'ou=group,'.$oss->{LDAP_BASE},
                        scope   => 'one',
                        filter  => '(groupType=class)',
                        attrs   => ['cn']
                     );
if( -d "/home/classes" )
{
	system("rm /home/classes/*/*");
	system("rm -r /home/classes/*");
	system("chmod 750 /home/classes/");
}
else
{
	system("mkdir -m 750 /home/classes");
}
system("chown root:teachers /home/classes");

foreach my $entry ( $mess->entries ) {
        my $cn = $entry->get_value('cn');
        system("mkdir -p -m 750 /home/classes/$cn");
        system("chown root:teachers /home/classes/$cn");
	 	
}

$mess = $oss->{LDAP}->search(
                        base    => 'ou=people,'.$oss->{LDAP_BASE},
                        scope   => 'one',
                        filter  => '(role=students)',
                        attrs   => ['uid','homedirectory']
                     );


foreach my $entry ( $mess->entries ) {
        my $uid  = $entry->get_value('uid');
        my $home = $entry->get_value('homedirectory');
        my $submessage = $oss->{LDAP}->search( base =>  'ou=group,'.$oss->{LDAP_BASE},
                           scope => 'one',
                           filter => "(&(groupType=class)(memberuid=$uid))",
                           attrs => ['cn']);
        foreach my $sub_entry ($submessage->all_entries) {
                  my $cn = $sub_entry->get_value('cn');
		  if( -d $home )
		  {
			  system("ln -s $home /home/classes/$cn/$uid");
                          system("setfacl -RPb $home; chgrp teachers $home; chmod 2771 $home;");
                          system("find $home ".'-type d -exec chgrp teachers {} \\;');
                          system("find $home ".'-type d -exec chmod 2771 {} \\;');
                          system("find $home ".'-type d -exec setfacl -dm g:teachers:rwx {} \\;');
			  system("mkdir -p $home/public_html; chmod 755 $home/public_html; chown $uid $home/public_html;");
		  }
		  else
		  {
		  	print STDERR " ERROR by $uid: Homedirectory $home do not exists\n";
		  }
        }
        print "modified : $uid\n";
}
