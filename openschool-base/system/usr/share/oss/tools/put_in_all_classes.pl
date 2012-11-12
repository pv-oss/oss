#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use oss_base;
use strict;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
			"all=s",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/put_in_all_classes.pl [OPTION]'."\n".
		'This script adds all the users in the every group.'."\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		"	No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'Optional parameters: '."\n".
		'	-h,  --help                 Display this help.'."\n".
		'	-d,  --description          Display the descriptiont.'."\n".
		'	     --all                  All class.'."\n";
}

if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	put_in_all_classes.pl'."\n".
		'DESCRIPTION:'."\n".
		'	This script adds all the users in the every group.'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"		                           : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h,  --help                : Display this help.(type=boolean)'."\n".
		'		-d,  --description         : Display the descriptiont.(type=boolean)'."\n".
		'		     --all                 : All class.(type=boolean)'."\n";
	exit 0;
}
my $all = 0;
if( defined($options{'all'}) ){
	$all = $options{'all'};
}

my $oss   = oss_base->new ({ withIMAP => 1 });
my $mess = $oss->{LDAP}->search(
                        base    => $oss->{SYSCONFIG}->{GROUP_BASE},
                        scope   => 'one',
                        filter  => '(&(groupType=class)(objectclass=schoolGroup))',
                        attrs   => ['dn']
                     );

my @CLASSES = ();
foreach my $entry ( $mess->entries ) {
  push @CLASSES, $entry->dn;
}

if( $all )
{
$mess = $oss->{LDAP}->search(
                        base    => $oss->{SYSCONFIG}->{USER_BASE},
                        scope   => 'one',
                        filter  => '(role=teachers)',
                        attrs   => ['dn','uid']
                     );
}
else
{
$mess = $oss->{LDAP}->search(
                        base    => $oss->{SYSCONFIG}->{USER_BASE},
                        scope   => 'one',
                        filter  => '(ou=all)',
                        attrs   => ['dn','uid']
                     );
}
foreach my $entry ( $mess->entries ) {
    my $uid             = $entry->get_value('uid');
    my $dn              = $entry->dn;
    $oss->{LDAP}->modify( $dn , replace => { ou    => 'all' } );
    foreach my $classdn ( @CLASSES )
    {
      print "Put user $uid into the classe: $classdn\n";
      $oss->add_user_to_group( $dn, $classdn );
    }
}
$oss->destroy;
