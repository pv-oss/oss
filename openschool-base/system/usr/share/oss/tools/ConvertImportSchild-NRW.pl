#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
			"convert_import_file=s",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/ConvertImportSchild-NRW.pl [OPTION]'."\n".
		'With this script we can convert the "Schild-NRW" file type into "CSV" file type. (The output results of this script will be in the "/tmp/userlist.txt" file.)'."\n\n".
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
		'	ConvertImportSchild-NRW.pl'."\n".
		'DESCRIPTION:'."\n".
		'	With this script we can convert the "Schild-NRW" file type into "CSV" file type. (The output results of this script will be in the "/tmp/userlist.txt" file.)'."\n".
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
	s/"//g;
	@line = split /;/;
	$Nachname = $line[1];
	$Vorname = $line[0];
	$Geb = $line[3];
	$Klasse = $line[4];
	$Klasse =~ s/^0//;
	print OUT "$Nachname:$Vorname:$Geb:$Klasse\n";
}
close OUT;
close FILE;
