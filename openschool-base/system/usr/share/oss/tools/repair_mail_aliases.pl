#!/usr/bin/perl  -w
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
			"group=s",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/repair_mail_aliases.pl [OPTION]'."\n".
		'Leiras ......'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		'	     --group         Group name.'."\n".
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
		'	repair_mail_aliases.pl'."\n".
		'DESCRIPTION:'."\n".
		'	Leiras ....'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		'		     --group         : Group name.(type=string)'."\n".
		'	OPTIONAL:'."\n".
		'		-h,  --help          : Display this help.(type=boolean)'."\n".
		'		-d,  --description   : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}
my $group = undef;
if( defined($options{'group'}) ){
	$group = $options{'group'};
}else{
	usage(); exit;
}


#Parse parameter
#my $group   = shift;
my $oss     = oss_base->new();
my $domain = $oss->get_school_config('SCHOOL_DOMAIN');
print $domain."\n";
my $groupDN = $oss->get_group_dn($group);

exit if !defined $groupDN;

print $groupDN."\n";
my $users = $oss->get_users_of_group($groupDN,1);
foreach my $user ( keys %{$users} ) {
  my $cn     = $users->{$user}->{cn}->[0];
  my $uid    = $users->{$user}->{uid}->[0];
  my $alias  = string_to_ascii($cn,1).'@'.$domain;
  if( $oss->is_unique($alias,'mail') )
  {
  	print "Create new alias for $cn: $alias\n";
	$oss->{LDAP}->modify( $user, add => { suseMailAcceptAddress => $alias });
  }
  else
  {
  	print STDERR "ERROR Can not Create alias: $alias exists already\n";
  }
  $oss->{LDAP}->modify( $user, add => { suseMailAcceptAddress => $uid.'@'.$domain });
}
$oss->destroy();
