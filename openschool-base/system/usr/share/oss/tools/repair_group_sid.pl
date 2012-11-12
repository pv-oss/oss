#!/usr/bin/perl  -w
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib"
}

use strict;
use oss_base;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
			"badSID=s",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/repair_group_sid.pl [OPTION]'."\n".
		'Leiras ....'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		"	No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'Optional parameters: '."\n".
		'	-h, --help         Display this help.'."\n".
		'	-d, --description  Display the descriptiont.'."\n".
		'	    --badSID       Bad SID.'."\n";
}
if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	repair_group_sid.pl'."\n".
		'DESCRIPTION:'."\n".
		'	Leiras ...'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"		                  : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h, --help        : Display this help.(type=boolean)'."\n".
		'		-d, --description : Display the descriptiont.(type=boolean)'."\n".
		'		    --badSID      : Bad SID.(type=string)'."\n";
	exit 0;
}
my $badSID  = '';
if( defined($options{'badSID'}) ){
	$badSID = $options{'badSID'};
}

#my $badSID  = shift || '';
my $oss  = oss_base->new();

# Make LDAP Connection

# Read some values from rcconfig
my $workgroup      = $oss->get_school_config("SCHOOL_WORKGROUP");

my $mesg = $oss->{LDAP}->search( base   => $oss->{LDAP_BASE},
			  filter => "(sambaDomainName=$workgroup)",
			  scope  => 'one',
			  attrs  => ['sambaSID']
			);
my $goodSID = $mesg->entry(0)->get_value('sambaSID');

if( $badSID eq '' ) {
  $mesg = $oss->{LDAP}->search( base   => $oss->{LDAP_BASE},
			  filter => "(sambaDomainName=PRINTSERVER)",
			  scope  => 'one',
			  attrs  => ['sambaSID']
			);
  if( !$mesg->count ) {
     die "No correcture neccesarry\n";
  }

  $badSID = $mesg->entry(0)->get_value('sambaSID');
}

if( $badSID eq "" || $goodSID eq "" ) {
   die "$badSID :: $goodSID\n";
}
print "correcture: $badSID :: $goodSID\n";

$mesg = $oss->{LDAP}->search( base   => $oss->{LDAP_BASE},
                       filter => "(objectclass=sambaGroupMapping)",
		       scope  => 'sub',
		       attrs  => ['sambaSID']
		     );

foreach my $entry ( $mesg->entries ) {
  my $SID = $entry->get_value('sambaSID');
  if( $SID =~ s/$badSID/$goodSID/ ) {
     $oss->{LDAP}->modify( $entry->dn(), replace => { sambaSID => $SID });
     print $entry->dn()." corrected\n";
  }
}
