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
	print   'Usage: /usr/share/oss/tools/ConvertImportSiBank.pl [OPTION]'."\n".
		'With this script we can convert the "SiBank" fike type into "CSV" file type. (The output results of this script will be in the "/tmp/userlist.txt" file.)'."\n".
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
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	ConvertImportSiBank.pl'."\n".
		'DESCRIPTION:'."\n".
		'	With this script we can convert the "SiBank" fike type into "CSV" file type. (The output results of this script will be in the "/tmp/userlist.txt" file.)'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		'		     --convert_import_file : File path.(type=string)'."\n".
		'	OPTIONAL:'."\n".
		'		-h,  --help                : Display this help.(type=boolean)'."\n".
		'		-d,  --description         : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}
my $datei = undef;
if( defined($options{'convert_import_file'}) ){
	$datei = $options{'convert_import_file'};
}else{
	usage(); exit;
}
#my ($datei) = @ARGV;

system("dos2unix $datei -c iso $datei") && die "convert of $datei failed\n";

open OUT,">/tmp/userlist.txt";
print OUT "NACHNAME:VORNAME:GEBURTSTAG:KLASSE\n";
open(FILE,"< $datei");
while(<FILE>) {
	s/"//g;
	s/^0//g;
	s/ //g;
	@line = split /,/;
	$Nachname = $line[1];
	$Vorname = $line[2];
	$Geb = $line[4];
	$Tag = substr($Geb,6,2);
	$Monat = substr($Geb,4,2);
	$Jahr = substr($Geb,0,4);
	$Klasse = $line[3];
	print OUT "$Nachname:$Vorname:$Tag.$Monat.$Jahr:$Klasse\n";
}
close OUT;
close FILE;
