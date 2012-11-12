#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

use strict;
use YaST::YCP qw(:LOGGING);
YaST::YCP::Import("Package");
use Data::Dumper;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
			"available_installed",
			"check_install_or_uninstall",
			"in",
			"rm",
			"packages=s",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/check_install_package.pl [OPTION] [PACKAGE]'."\n".
		'With this script we can check if a package exists or has been installed on the server. Also we can check we want to install or uninstall it.'."\n".
		'Ex:    "./check_install_package.pl --available_installed --packages=oss_clax"'."\n".
		'    or "./check_install_package.pl --check_install_or_uninstall --packages=oss_clax"'."\n".
		'    or "./check_install_package.pl --in --packages=oss_clax")'."\n".
		'    or "./check_install_package.pl --rm --packages=oss_clax")'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		'	     --available_installed         Checks if the package is installed'."\n".
		'	     --check_install_or_uninstall  Returns "in" if the package can be installed'."\n".
		'	                                   Returns "rm" if the package can be deinstalled'."\n".
		'	                                   Returns "0"  if the package is not available'."\n".
		'	     --in                          Install a package'."\n".
		'	     --rm                          Deinstall a package'."\n".
		'	     --packages                    Packages name.'."\n".
		'Optional parameters: '."\n".
		'	-h,  --help                        Display this help.'."\n".
		'	-d,  --description                 Display the descriptiont.'."\n";
}

if( defined($options{'help'}) ) {
	usage();
	exit 0;
}
elsif( defined($options{'description'}) )
{
	print   'NAME:'."\n".
		'	check_install_package.pl'."\n".
		'DESCRIPTION:'."\n".
		'	With this script we can check if a package exists or has been installed on the server. Also we can check we want to install or uninstall it.'."\n".
                'Ex:    "./check_install_package.pl --available_installed --packages=oss_clax"'."\n".
                '    or "./check_install_package.pl --check_install_or_uninstall --packages=oss_clax"'."\n".
                '    or "./check_install_package.pl --in --packages=oss_clax")'."\n".
                '    or "./check_install_package.pl --rm --packages=oss_clax")'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		'		     --available_installed        : Checks if the package is installed.(type=boolean)'."\n".
		'		     --check_install_or_uninstall : Returns "in" if the package can be installed.(type=boolean)'."\n".
		'		                                  : Returns "rm" if the package can be deinstalled'."\n".
		'		                                  : Returns "0"  if the package is not available'."\n".
		'		     --in                         : Install a package.(type=boolean)'."\n".
		'		     --rm                         : Deinstall a package.(type=boolean)'."\n".
		'		     --packages                   : Packages name.(type=string)'."\n".
		'	OPTIONAL:'."\n".
		'		-h,  --help                       : Display this help.(type=boolean)'."\n".
		'		-d,  --description                : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}
elsif( defined($options{'available_installed'}) and defined($options{'packages'}) )
{
	my $package = $options{'packages'};
	if( Package->Installed("$package") ){
		print 1;
		exit;
	}else{
		print 0;
		exit;
	}
}
elsif( defined($options{'check_install_or_uninstall'}) and defined($options{'packages'}) )
{
	my $package = $options{'packages'};
	if( Package->Available("$package") ){
		if( Package->Installed("$package") ){
			print "rm";
			exit;
		}else{
			print "in";
			exit;
		}
	}else{
		print 0;
		exit;
	}
}
elsif( defined($options{'rm'}) and defined($options{'packages'}) )
{
	my @packages = $options{'packages'};
#	print Dumper(@packages)."\n";exit;
	print join(":",@packages)."\n";
	Package->DoRemove(\@packages);
}
elsif( defined($options{'in'}) and defined($options{'packages'}) )
{
	my @packages = $options{'packages'};
	Package->DoInstall(\@packages);
}
else
{
	usage();
}
