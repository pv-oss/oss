#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2005 Peter Varkoly Fuerth, Germany.  All rights reserved.
#
# $Id: oss_set_passwd.pl,v 1.6 2007/02/09 17:58:12 pv Exp $
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use Getopt::Long;
use oss_base;
use oss_utils;

# Make LDAP Connection
my $oss = oss_base->new();

# Global variable
my $uid     = undef;
my $class   = undef;

if( $ARGV[0] eq '-' )
{
	while(<STDIN>)
	{
	  # Clean up the line!
	  chomp; s/^\s+//; s/\s+$//;

	  my ( $key, $value ) = split / /,$_,2;

	  if( $key eq 'uid' )
	  {
		$uid = $value;
	  }
	  elsif ( $key eq 'class' )
	  {
		$class = $value;
	  }

	}
}
else
{
	# Parsing the attributes
	my %options    = ();
	my $result = GetOptions(\%options,
	                      "help",
	                      "description",
	                      "uid=s",
	                      "class=s"
	                      );
	
	if (!$result && ($#ARGV != -1))
	{
	      usage();
	      exit 1;
	}
	if ( defined($options{'help'}) ) {
	      usage();
	      exit 0;
	}
	if( defined($options{'description'}) ){
	      description();
	      exit 0;
	}
	if ( defined($options{'class'}) )
	{
	      $class=$options{'class'};
	}
	if ( defined($options{'uid'}) )
	{
	      $uid=$options{'uid'};
	}
}

if( !$uid || !$class )
{
  usage();
  exit 0;
}

##############################################################################
## Print the option usage
sub usage {
	print   "Usage: /usr/share/oss/tools/add_rights_to_teacher.pl [OPTION]\n";
		"With this script we can grant access for a teacher to access a specific group member's library.\n\n".
		"Options :\n".
		'Mandatory parameters :'."\n".
		"	     --uid          the concerned teacher\n".
		"	     --class        the concerned class\n".
		'Optional parameters: '."\n".
		'	-h,  --help         Display this help.'."\n".
		'	-d,  --description  Display the descriptiont.'."\n\n".
		"Otherwise you can pipe the attributes on STDIN (it is safer). In this case use '-' as option:\n\n".
		"echo \"uid bigboss\n".
		"class 5A\" | add_rights_to_teacher.pl\n";
}

sub description {
	print   'NAME:'."\n".
		'	add_rights_to_teacher.pl'."\n".
		'DESCRIPTION:'."\n".
		"	With this script we can grant access for a teacher to access a specific group member's library.\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		'		     --uid         : The concerned teacher.(type=string)'."\n".
		'		     --class       : The concerned class.(type=string)'."\n".
		'	OPTIONAL:'."\n".
		'		-h,  --help        : Display this help.(type=boolean)'."\n".
		'		-d,  --description : Display the descriptiont.(type=boolean)'."\n";
}
##############################################################################
# now we start to work

foreach my $dn  ( $oss->get_students_of_group($oss->get_group_dn($class)) )
{
    my $home = $oss->get_attribute($dn,'homeDirectory');   
    system("setfacl -P -R -m m::rwx $home");
    next if ( $home !~ /^\/home\/students/);
    system("setfacl -R -P -m u:$uid:rwx $home");
    print "setfacl -R -P -m u:$uid:rwx $home\n";
}
$oss->destroy();
