#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# (c) 2011 EXTIS GmbH
# Revision: $Rev:  $

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

use strict;
use oss_base;
use oss_utils;
use Config::IniFiles;
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
	print   'Usage: /usr/share/oss/tools/set_trigger_script.pl [OPTION]'."\n".
		'This script assigns the "trigger" scripts in the "GlobalConfiguration" module elements.'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		"	No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'Optional parameters: '."\n".
		'	-h, --help         Display this help.'."\n".
		'	-d, --description  Display the descriptiont.'."\n";
}
if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	set_trigger_script.pl'."\n".
		'DESCRIPTION:'."\n".
		'	This script assigns the "trigger" scripts in the "GlobalConfiguration" module elements.'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"		                  : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h, --help        : Display this help.(type=boolean)'."\n".
		'		-d, --description : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}

my $this = oss_base->new();
my $file = '/usr/share/oss/tools/triger_script_list.ini';
if( !(-e "$file") ){
	print "Could not open $file!\n";
	exit;
}
my %ini_hash;
tie %ini_hash, 'Config::IniFiles', ( -file => "$file" );

foreach my $section ( keys %ini_hash ){
	foreach my $item ( keys %{$ini_hash{$section}}){
		$this->delete_vendor_object( "configurationKey=$item,$this->{SYSCONFIG_BASE}", 'EXTIS', 'TriggerScript' );
		next if( !$ini_hash{$section}->{$item} );
		my @scipts = split(";", $ini_hash{$section}->{$item});
		foreach my $script (@scipts){
			my $obj = $this->search_vendor_object_for_vendor( "TriggerScript", "configurationKey=$item,$this->{SYSCONFIG_BASE}");
			if( $obj ){
				$this->add_value_to_vendor_object( "configurationKey=$item,$this->{SYSCONFIG_BASE}", 'EXTIS', 'TriggerScript', "$script");
			}else{
				$this->create_vendor_object( "configurationKey=$item,$this->{SYSCONFIG_BASE}", 'EXTIS', 'TriggerScript', "$script" );
			}
		}
	}
}
