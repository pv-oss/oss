#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2002 SuSE Linux AG Nuernberg, Germany.  All rights reserved.
# Copyright (c) 2000-2001 SuSE GmbH Nuernberg, Germany.  All rights reserved.
#
# Workaround - Ausgabe angepasst zur Auflistung der Mailquota fuer die HITS-Datenbank
# (ME 09.02.2011)
#
# $Id: report_quota.pl,v 2.0.0.1 2005/01/21 13:08:36 pv Exp $
#

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

use strict;
use POSIX qw(strftime);
use oss_utils;


#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
			"mode=s",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/report_quota.pl [OPTION]'."\n".
		'Analyse the mailbox quota files and makes a report or warnings.'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		"	No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'Optional parameters: '."\n".
		'	-h, --help         Display this help.'."\n".
		'	-d, --description  Display the descriptiont.'."\n".
		'	    --mode         Mode:  report|warning.'."\n";
}
if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	report_quota.pl'."\n".
		'DESCRIPTION:'."\n".
		'	Analyse the mailbox quota files and makes report or warnings'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"		                  : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h, --help        : Display this help.(type=boolean)'."\n".
		'		-d, --description : Display the descriptiont.(type=boolean)'."\n".
		'		    --mode        : Mode. report|warning (type=string)'."\n";
	exit 0;
}
my $mode  = 'warning';
if( defined($options{'mode'}) ){
        $mode = $options{'mode'};
}
my $filter = "";
my $mbody  = "";
my $lang   = `. /etc/sysconfig/language ; echo \$RC_LANG`;
my $imaplib = "/var/lib/imap";
my %ulist  = ();

my $qwarn = (parse_file("/etc/imapd.conf", "quotawarn:"))[0];

if( ! defined $qwarn || $qwarn eq "" ) {
    print STDERR "unable to read quotawarn from /etc/imapd.conf\n";
    exit;
}

my @allfiles;
get_files_recursive("$imaplib/quota",\@allfiles);

foreach my $f (@allfiles) {
    if( $f =~ /.*\.(.*)/ ) {
	my $uid = $1;
	if(defined $uid && $uid ne "") {
	    open(Q, "$f");
	    my @qv = <Q>;
	    close(Q);
	    next if ! defined $qv[0];
	    chomp(@qv);
	    my $used  = ($qv[0]/1024);
	    my $total = $qv[1];

	    $ulist{$uid}{limit} = $total;
	    $ulist{$uid}{used}  = int($used);
	    $ulist{$uid}{pused} = int($used/$total*100);
	    $ulist{$uid}{warn}  = $qwarn;
	}
    }
}

my $date = strftime("%a, %d %b %Y %H:%M:%S %z\n",localtime);
    
if( $lang eq "DE" ) {
    $mbody ="To: \$uid
From: mailadmin
Subject: Automatischer Quota Report
Reply-To: mailadmin
Date: $date

Die groesse Ihrer Mailbox hat den im System definierten Warning Level
ueberschritten. Bitte loeschen Sie ein paar Mails.

Quota Report fuer Ihre Mailbox:

Max. Quota verfuegbar = \$ulist{\$uid}{limit} (KBytes)
Quota in Gebrauch     = \$ulist{\$uid}{used} (KBytes)
Quota Warning Level   = \$ulist{\$uid}{warn}%
Quota in Gebrauch     = \$ulist{\$uid}{pused}%
";
} else {
    $mbody ="To: \$uid
From: mailadmin
Subject: Automatic Quota Report
Reply-To: mailadmin
Date: $date

Your mailbox size has reached the system defined quota warning level.
Please delete some mails.

Quota usage report for your mailbox:

Max. Quota available = \$ulist{\$uid}{limit} (KBytes)
Quota used           = \$ulist{\$uid}{used} (KBytes)
Quota warning level  = \$ulist{\$uid}{warn}%
Quota in use         = \$ulist{\$uid}{pused}%
";
}
if( $mode eq 'report' )
{
	$mbody ="\$uid;\$ulist{\$uid}{limit};\$ulist{\$uid}{used};\$ulist{\$uid}{pused}%
";
}
foreach my $uid (keys %ulist) {
  
    if( $mode eq 'report' )
    {
	my $eval = eval "sprintf \"%s\", \"$mbody\"";
	print $eval;
	next;
    }
    if( $ulist{$uid}{pused} > $ulist{$uid}{warn} ) {
	my $eval = eval "sprintf \"%s\", \"$mbody\"";
	if( ! open(OUT, "| /usr/lib/cyrus/bin/deliver -q -r mailadmin -a cyrus $uid") ) {
	    print STDERR "ERROR sending quota warning to $uid: $!\n";
	}
	print OUT $eval;
	close(OUT);
    }
}

1;
