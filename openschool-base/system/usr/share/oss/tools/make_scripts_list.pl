#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# (c) 2011 EXTIS GmbH
# Revision: $Rev: 1490 $

BEGIN{
    push @INC,"/usr/share/oss/lib/";
}
use strict;
use oss_utils;
use Data::Dumper;
use XML::Writer;
use IO;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
				"help",
				"description",
			);
sub usage
{
	print   'Usage: /usr/share/oss/tools/make_scripts_list.pl [OPTION]'."\n".
		'With this script we can refresh the content of "scripts_list.xml". (In the AdminTools module the scripts are listed by the  "scripts_list.xml" file.)'."\n\n".
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
		'	make_scripts_list.pl'."\n".
		'DESCRIPTION:'."\n".
		'	With this script we can refresh the content of "scripts_list.xml". (In the AdminTools module the scripts are listed by the  "scripts_list.xml" file.)'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"		                  : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h, --help        : Display this help.(type=boolean)'."\n".
		'		-d, --description : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}

my $date = `date +%Y-%m-%d.%H-%M-%S`; chop $date;
open STDIN,"/dev/null";
open STDOUT,">>/var/log/make_scripts_list.log";
open STDERR,">>/var/log/make_scripts_list.log";
print  "\n\n----------------------------------  $date  ------------------------------------\n";

my $output = new IO::File(">/usr/share/oss/tools/scripts_list.xml");
my $writer = new XML::Writer(OUTPUT => $output, DATA_MODE => 1, DATA_INDENT=>1 );
$writer->xmlDecl( 'UTF-8' );
$writer->startTag("Script_List");
foreach my $line ( sort ( glob "/usr/share/oss/tools/*" ) ){
#if( $line eq "/usr/share/oss/tools/add_room_to_tfk.pl"){
	my $result = '';
	my $flag_name  = `grep 'NAME:' $line`; 
	my $flag_des   = `grep 'DESCRIPTION:' $line`;
	my $flag_param = `grep 'PARAMETERS:' $line`;
	if( $flag_name and $flag_des and $flag_param ){
		print $line."\n";
		$result = cmd_pipe("$line --description");
	}else{
		print "\t".$line."\n";
		next;
	}

	my @tmp = split( /([A-Z]{4,20}\:\n)/, $result);
	#name
	my $s_name   = trim($tmp[2]);
	#description
	my $s_desc   = trim($tmp[4]);
	#mandatory patameters
	my $mandatory_param = split_parameter($tmp[8]);
	#optional parameters
	my $optional_param  = split_parameter($tmp[10]);

	$writer->startTag("$s_name");
		$writer->startTag("NAME");
                        $writer->characters("$s_name");
                $writer->endTag("NAME");
		$writer->startTag("DESCRIPTION");
			$writer->characters("$s_desc");
		$writer->endTag("DESCRIPTION");
		$writer->startTag("PARAMETERS");
			$writer->startTag("MANDATORY");
				$writer->characters("$mandatory_param");
			$writer->endTag("MANDATORY");
			$writer->startTag("OPTIONAL");
				$writer->characters("$optional_param");
			$writer->endTag("OPTIONAL");
                $writer->endTag("PARAMETERS");
	$writer->endTag("$s_name");
#}
}
$writer->endTag("Script_List");
$writer->end();
$output->close();


sub split_parameter
{
	my $pram_string = shift;

	my %hash;
	my $tmp_param_name = '';
	my @parameters = split( "\n", $pram_string );
	foreach my $param ( @parameters ){
		$param = trim($param);
		my ($s_param_n, $s_param_d) = '';
		if( $param =~ /(.*)--(.*):(.*)/ ){
			$s_param_n = trim($2);
			$s_param_d = trim($3);
			$hash{$s_param_n} = $s_param_d;
			$tmp_param_name = $s_param_n;
		}else{
			next if ($param eq undef );
			$param =~ /(.*):(.*)/;
			$s_param_d = trim($2);
			$hash{$tmp_param_name} .= ", ".$s_param_d;
		}
	}

	my $s_params = '';
	foreach my $param ( keys %hash ){
		if( $param eq undef ){
			$hash{$param} =~ s/, //;
			return $hash{$param};
		}
		$s_params .= $param."==".$hash{$param}.";";
	}
	return $s_params;
}

sub trim($)
{
        my $string = shift;
        $string =~ s/^\s+//;
        $string =~ s/\s+$//;
        return $string;
}
