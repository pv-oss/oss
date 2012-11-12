#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# (c) 2011 EXTIS GmbH
# Revision: $Rev: 1488 $

BEGIN{ push @INC,"/usr/share/oss/lib/";}
use strict;
use oss_utils;
use DBI;
use Data::Dumper;
my $date = `date +%Y-%m-%d.%H-%M-%S`;
chop $date;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/insert_pagelog_in_database.pl [OPTION]'."\n".
		'This script fills the "PrintigLog" table with data from the "/var/log/cups/page_log" file.'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		"	No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'Optional parameters : '."\n".
		'	-h,  --help            Display this help.'."\n".
		'	-d,  --description     Display the descriptiont.'."\n";
}

if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	insert_pagelog_in_database.pl'."\n".
		'DESCRIPTION:'."\n".
		'	This script fills the "PrintigLog" table with data from the "/var/log/cups/page_log" file.'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"				     : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h,  --help          : Display this help.(type=boolean)'."\n".
		'		-d,  --description   : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}

open STDIN,"/dev/null";
open STDOUT,">>/var/log/insert_pagelog_in_database.log";
open STDERR,">>/var/log/insert_pagelog_in_database.log";
print  "\n\n----------------------------------  $date  ------------------------------------\n";

#connect database
my ($MYSQLPW)= parse_file('/root/.my.cnf',"password=");
my $DBH = DBI->connect( 'dbi:mysql:lmd', 'root', $MYSQLPW);

#check "/var/log/cups/page_log" file
my $pagelog_file = '/var/log/cups/page_log';
if( !(-e $pagelog_file) ){
	print "File does not exist: $pagelog_file!";
	exit;
}

#read "/var/log/cups/page_log" file and insert in to database
open(FILE,"< $pagelog_file") or die "Can't open $pagelog_file!\n";
while(<FILE>){
	my $row = trim($_);
	if($row =~ /([0-9a-zA-Z._-]{1,}) ([0-9a-zA-Z._-]{1,}) ([0-9]{1,}) (\[.*\]) ([0-9a-zA-Z]{1,}) ([0-9]{1,})([ ]{1}){0,}([a-zA-Z]{0,}-[0-9]{0,}){0,}([ ]{1}){0,}([a-zA-Z]{1,}){0,}([ ]{1}){0,}([0-9a-zA-Z]{1,}){0,}([ ]{1}){0,}([0-9a-zA-Z]{1,}){0,}([ ]{1}){0,}([0-9a-zA-Z]{0,}-[0-9a-zA-Z]{0,}){0,}/){
		my $Printer = $1;
		my $User = $2;
		my $JobId = $3;
		my $PageNumber = $5;
		my $NumCopies = $6;
		my $JobBilling = $8;
		my $JobOriginatingHostName = $10;
		my $JobName = $12;
		my $Media = $14;
		my $Sides = $16;
		$4 =~ m/(\[)([0-9]{2})(\/)([a-zA-Z]{1,3})(\/)([0-9]{4})(:)([0-9]{2}:[0-9]{2}:[0-9]{2})/;
		my $DateTime = $6.'-month-'.$2.' '.$8;
		my $month = $4;
		$month =~ s/Jan/01/;$month =~ s/Feb/02/;$month =~ s/Mar/03/;$month =~ s/Apr/04/;$month =~ s/Mai/05/;$month =~ s/May/05/;$month =~ s/Jun/06/;$month =~ s/Jul/07/;$month =~ s/Aug/08/;$month =~ s/Sep/09/;$month =~ s/Oct/10/;$month =~ s/Nov/11/;$month =~ s/Oct/11/;$month =~ s/Dec/12/;
		$DateTime =~ s/month/$month/;

		my $sth = $DBH->prepare("SELECT * FROM PrintingLog WHERE Printer='$Printer' and User='$User' and JobId='$JobId' and DateTime='$DateTime' and PageNumber=$PageNumber and NumCopies='$NumCopies' and JobBilling='$JobBilling' and JobOriginatingHostName='$JobOriginatingHostName' and JobName='$JobName' and Media='$Media' and Sides='$Sides'");
		$sth->execute();
		my $hashref = $sth->fetchrow_hashref();
		if( !${$hashref}{Id} ){
			my $sth1 = $DBH->prepare("SELECT * FROM PrintingLog WHERE Printer='$Printer' and User='$User' and JobId='$JobId'");
			$sth1->execute();
			$hashref = $sth1->fetchrow_hashref();
			if( ${$hashref}{Id} ){
				my $sth2 = $DBH->prepare("UPDATE PrintingLog set PageNumber=${$hashref}{PageNumber}+1 where Id='${$hashref}{Id}'");
				$sth2->execute();
			}else{
				my $sth2 = $DBH->prepare("INSERT INTO PrintingLog (Id, Printer, User, JobId, DateTime, PageNumber, NumCopies, JobBilling, JobOriginatingHostName, JobName,  Media, Sides, RecordType, PaymentId, Price) VALUES(NULL, '$Printer', '$User', $JobId, '$DateTime', '$PageNumber', $NumCopies, '$JobBilling', '$JobOriginatingHostName', '$JobName', '$Media', '$Sides', '', '0', '0')");
				$sth2->execute;
			}
		}else{}
	}else{
		print "Not correct row in the file ( $row ) \n";
		exit;
	}
}
close (FILE);

#save old page_log file and creat new empty page_log file
my( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst ) = localtime(time);
my $datetime = sprintf('%4d-%02d-%02d_%02d:%02d:%02d',$year+1900,$mon+1,$mday,$hour,$min,$sec);
cmd_pipe("mv $pagelog_file $pagelog_file-$datetime");
cmd_pipe("touch $pagelog_file");


sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}
