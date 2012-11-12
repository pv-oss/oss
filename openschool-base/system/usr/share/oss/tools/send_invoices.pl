#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# (c) 2011 EXTIS GmbH
# Revision: $Rev: 1475 $

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

use strict;
use oss_base;
use oss_utils;
use Config::IniFiles;
use DBI;
use Data::Dumper;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
			"act_user_dn=s",
			"via_email",
			"in_home_directory",
			"printer=s",
			"users=s",
			"lang=s",
		);
sub usage
{
        print   'Usage: /usr/share/oss/tools/send_invoices.pl [OPTION]'."\n".
		'This script creates the invoices In PDF format for the "PrinterPriceManagement" module.'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		'	     --act_user_dn     That users dn who calls the script.'."\n".
		'	     --via_email       Seding the invoice via email.'."\n".
		'	     --in_home_directory Copying the invoice to the users home directory.'."\n".
		'	     --printer         Printing the invoice now.'."\n".
		'	     --users           The users name who gets the invoice.'."\n".
		'	     --lang            That users language settings, who calls this script.'."\n".
		'Optional parameters : '."\n".
		'	-h,  --help            Display this help.'."\n".
		'	-d,  --description     Display the descriptiont.'."\n";
}

if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	send_invoices.pl'."\n".
		'DESCRIPTION:'."\n".
		'	This script creates the invoices In PDF format for the "PrinterPriceManagement" module.'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		'		     --act_user_dn   : That users dn who calls the script.(type=string)'."\n".
		'		     --via_email     : Seding the invoice via email.(type=boolean)'."\n".
		'		     --in_home_directory : Copying the invoice to the users home directory.(type=boolean)'."\n".
		'		     --printer       : Printing the invoice now.(type=string)'."\n".
		'		     --users         : The users name who gets the invoice.(type=string)'."\n".
		'		     --lang          : That users language settings, who calls this script.(type=string)'."\n".
		'	OPTIONAL:'."\n".
		'		-h,  --help          : Display this help.(type=boolean)'."\n".
		'		-d,  --description   : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}
my $act_user_dn = undef;
my $via_email = undef;
my $in_home_directory = undef;
my $printer   = undef;
my $users_str = undef;
my $message   = {};
my $lang      = 'EN';
if( defined($options{'via_email'}) ){
	$via_email = 1;
}
if( defined($options{'in_home_directory'}) ){
	$in_home_directory = 1;
}
if( defined($options{'printer'}) ){
	$printer = $options{'printer'};
}
if ( defined($options{'lang'}) )
{
	$lang = $options{'lang'};
}
if( defined($options{'act_user_dn'}) ){
        $act_user_dn = $options{'act_user_dn'};
}else{
	usage(); exit 0;
}
if( defined($options{'users'}) ){
	$users_str = $options{'users'};
}else{
	usage(); exit 0;
}

cmd_pipe('touch /var/adm/oss/invoices_send');

# Setup the messages
my $allmessages = new Config::IniFiles( -file => '/usr/share/lmd/lang/base_'.$lang.'.ini' );
my @parameters = $allmessages->Parameters('PrinterPriceManagement');
foreach(@parameters)
{
	my $value = $allmessages->val('PrinterPriceManagement', $_);
#	$message->{lc($_)} = decode("utf8",$value);
	$message->{lc($_)} = $value;
}

sub __($)
{
	my $i = shift;
	return $message->{$i} ? $message->{$i} : $i;
}


#connect database
my ($MYSQLPW)= parse_file('/root/.my.cnf',"password=");
my $DBH = DBI->connect( 'dbi:mysql:lmd', 'root', $MYSQLPW);
my $oss = oss_base->new();

my $report_url = "/usr/share/lmd/tools/JavaBirt/Reports/PrinterPriceManagement.rptdesign";
my @users = split /,/, $users_str;

my $where .= ' and ( ';
foreach my $user ( sort @users){
	$where .= ' or ';
	$where .= "User='$user'";
}
$where .= ' )';
$where =~ s/ or //;

my $sth = $DBH->prepare("SELECT Id, InvoiceNumber, User, DateOfPayment, PaymentSum FROM PrintingPayment WHERE DateOfPayment='0000-00-00 00:00:00' $where");
$sth->execute;

my $hash;
while (my $hashref = $sth->fetchrow_hashref() ){
	my $payment_id = ${$hashref}{Id};
	my $user = ${$hashref}{User};
	my $invoice_number = ${$hashref}{InvoiceNumber};
	my $user_dn = $oss->get_user_dn($user);

	my $cmd = "java -jar /usr/share/lmd/tools/JavaBirt/JavaBirt.jar REPORT_URL=$report_url COMMAND=EXECUTE OUTPUT=pdf #DB_DRIVERCLASS=com.mysql.jdbc.Driver #DB_URL=jdbc:mysql://localhost/lmd #DB_USER=root #DB_PWD=$MYSQLPW PAYMENT_ID=$payment_id";
        my $result = cmd_pipe("$cmd");

	if($result){
		print $result;
		exit;
	}else{
		my $tmp_file_path = '/tmp/'.$user.__('_invoice_').$invoice_number.".pdf";
		cmd_pipe("cp /usr/share/lmd/tools/JavaBirt/Reports/PrinterPriceManagement.pdf $tmp_file_path");
		cmd_pipe("rm /usr/share/lmd/tools/JavaBirt/Reports/PrinterPriceManagement.pdf");
		if($via_email){
			my $subject = __('invoce_mail_subject');
			my $user_mail_from = $oss->get_attribute( $act_user_dn,'mail');
			my $user_mail_to = $oss->get_attribute($user_dn,'mail');
			my $SEND_INVOCE =   'SUBJECT="'.$subject."\"\n".
					'INVOICE="'.$tmp_file_path."\"\n".
					'MAILFROM="'.$user_mail_from."\"\n".
					'MAILTO="'.$user_mail_to."\"\n";
			write_file('/tmp/SEND_INVOCE',$SEND_INVOCE);
			my $SEND_INVOCE_BODY = __('invoce_mail_body');
			write_file('/tmp/SEND_INVOCE-BODY',$SEND_INVOCE_BODY);

		        system('/usr/share/oss/tools/send_invoice_to_mail');
		}
		if($in_home_directory){
			my $name = `basename '$tmp_file_path'`; chomp $name;
			my $user_home_dir = $oss->get_attribute($user_dn,'homeDirectory')."/".$name;
			cmd_pipe("cp $tmp_file_path $user_home_dir");
		}
		if($printer){
			system("lpr -P $printer $tmp_file_path");
		}
		cmd_pipe("rm $tmp_file_path");
	}
}
cmd_pipe('rm /var/adm/oss/invoices_send');
