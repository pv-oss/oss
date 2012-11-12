#!/usr/bin/perl  -w
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/"
}

use strict;
use oss_base;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
			"start=s",
			"end=s",
			"int=s",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/set_ox_calender.pl [OPTION]'."\n".
		'This script sets the openxchange calendar.'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		'	     --start          OXDayviewStartTime.(Ex: --start=00:30)'."\n".
		'	     --end            OXDayviewEndTime.(Ex: --end=22:30)'."\n".
		'	     --int            OXDayviewInterval.(Ex: --int=10)'."\n".
		'Optional parameters: '."\n".
		'	-h,  --help          Display this help.'."\n".
		'	-d,  --description   Display the descriptiont.'."\n";
}
if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) )
{
	print   'NAME:'."\n".
		'	set_ox_calender.pl'."\n".
		'DESCRIPTION:'."\n".
		'	This script sets the openxchange calendar.'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		'		     --start         : OXDayviewStartTime.(Ex: --start=00:30)(type=string)'."\n".
		'		     --end           : OXDayviewEndTime.(Ex: --end=22:30)(type=string)'."\n".
		'		     --int           : OXDayviewInterval.(Ex: --int=10)(type=string)'."\n".
		'	OPTIONAL:'."\n".
		'		-h,  --help          : Display this help.(type=boolean)'."\n".
		'		-d,  --description   : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}
my $start = undef;
my $end   = undef;
my $int   = undef;

if( defined($options{'start'}) ){
        $start = $options{'start'};
}else{
        usage(); exit;
}
if( defined($options{'end'}) ){
        $end = $options{'end'};
}else{
        usage(); exit;
}
if( defined($options{'int'}) ){
        $int = $options{'int'};
}else{
        usage(); exit;
}

my $oss   = oss_base->new();

my $mesg = $oss->{LDAP}->search( base   => $oss->{SYSCONFIG}->{USER_BASE},
                       filter => "(objectclass=OXUserObject)",
		       scope  => 'one',
		     );

foreach my $entry ( $mesg->entries ) {
     if( $entry->exists('OXDayviewStartTime') )
     {
        $entry->replace( OXDayviewStartTime => $start )
     }
     else
     {
        $entry->add( OXDayviewStartTime => $start )
     }
     if( $entry->exists('OXDayviewEndTime') )
     {
        $entry->replace( OXDayviewEndTime => $end )
     }
     else
     {
        $entry->add( OXDayviewEndTime => $end )
     }
     if( $entry->exists('OXDayviewInterval') )
     {
        $entry->replace( OXDayviewInterval => $int )
     }
     else
     {
        $entry->add( OXDayviewInterval => $int )
     }
     $entry->update( $oss->{LDAP} );
     print $entry->dn()." corrected\n";
}
$oss->destroy();
