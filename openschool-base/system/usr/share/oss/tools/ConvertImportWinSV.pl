#!/usr/bin/perl -w
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

#Parse parameter
use strict;
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
			"convert_import_file=s",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/ConvertImportWinSV.pl [OPTION]'."\n".
		'With this script we can convert the "WinSV" file type into "CSV" file type. (The output results of this script will be in the "/tmp/userlist.txt" file.)'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		'	     --convert_import_file  File path.'."\n".
		'Optional parameters: '."\n".
		'	-h,  --help                 Display this help.'."\n".
		'	-d,  --description          Display the descriptiont.'."\n";
}

if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) )
{
	print   'NAME:'."\n".
		'	ConvertImportWinSV.pl'."\n".
		'DESCRIPTION:'."\n".
		'	With this script we can convert the "WinSV" file type into "CSV" file type. (The output results of this script will be in the "/tmp/userlist.txt" file.)'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		'		     --convert_import_file : File path.(type=string)'."\n".
		'	OPTIONAL:'."\n".
		'		-h,  --help                : Display this help.(type=boolean)'."\n".
		'		-d,  --description         : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}
my $import_file = undef;
if( defined($options{'convert_import_file'}) ){
	$import_file = $options{'convert_import_file'};
}else{
	usage(); exit;
}

open OUT,">/tmp/userlist.txt";
print OUT "NACHNAME:VORNAME:GEBURTSTAG:KLASSE\n";
open(FILE,"< $import_file");
while(<FILE>) {
	s/,(\d+),/:$1:/g;
	s/","/:/g;
        s/"//g;	
        s/,/ /g;	
	my @line = split /:/;
	my $Klasse = $line[52] || $line[53];
	$Klasse =~ s/^0//g;
	$Klasse =~ s/ //g;
	$Klasse =~ s/\//-/g;
	$Klasse = uc($Klasse);
	print OUT "$line[3]:$line[6]:$line[10]:$Klasse\n";
}
close OUT;
close FILE;
