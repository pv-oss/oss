#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

BEGIN{
  push @INC,"/usr/share/oss/lib/";
}

use oss_base;
use oss_utils;
use Net::LDAP;
use Data::Dumper;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/get_attributes.pl [OPTION]'."\n".
		'With this script  we can request the attributes.'."\n\n".
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
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	get_attributes.pl'."\n".
		'DESCRIPTION:'."\n".
		'	With this script  we can request the attributes.'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"			           : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h,  --help        : Display this help.(type=boolean)'."\n".
		'		-d,  --description : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}

my @groupClasses = qw (  top posixgroup schoolgroup phpgwaccount susemailrecipient sambagroupmapping groupofnames );
my $oss = oss_base->new();
my $schema = $oss->{LDAP}->schema();
my $attrs  = {};
foreach my $attr ( $schema->all_objectclasses)
{
    my $name = lc( $attr->{name});
    if( contains($name,\@groupClasses) )
    {
	foreach( @{$attr->{must}} )
	{
	    $attrs->{lc()} = 1;
	}
	foreach( @{$attr->{may}} )
	{
	    $attrs->{lc()} = 1;
	}
    }
}
@lattr = sort( keys %$attrs );
print join "\n", @lattr;
