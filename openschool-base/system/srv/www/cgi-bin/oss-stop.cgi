#!/usr/bin/perl
#
# Sample CGI to explain to the user that the URL is blocked and by which rule set
#
# By Pål Baltzersen 1998
#
# Localised by Lars Rupp 2003
#
use Config::IniFiles;

$LANG = `. /etc/sysconfig/language ; echo \$RC_LANG`;
$LANG = substr($LANG,3,2);


$QUERY_STRING = $ENV{'QUERY_STRING'};
$DOCUMENT_ROOT = '/srv/www/admin';

$clientaddr = "";
$clientname = "";
$clientident = "";
$srcclass = "";
$targetclass = "";
$url = "";
$time = time;
@day = ("Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday");
@month = ("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");

while ($QUERY_STRING =~ /^\&?([^&=]+)=([^&=]*)(.*)/) {
  $key = $1;
  $value = $2;
  $QUERY_STRING = $3;
  if ($key =~ /^(clientaddr|clientname|clientident|srcclass|targetclass|url)$/) {
    eval "\$$key = \$value";
  }
  if ($QUERY_STRING =~ /^url=(.*)/) {
    $url = $1;
    $QUERY_STRING = "";
  }
}

my $cfg =  new Config::IniFiles( -file => "/usr/share/lmd/lang/squidguard_$LANG.ini" );
if( defined $cfg )
{
	$targetclass = $cfg->val( 'squidGuard', $targetclass) if ( $cfg->val( 'squidGuard', $targetclass) );
}

if( ! $clientname )
{
	$clientname = `host $clientaddr | gawk '{print \$5}'`;
}

if ($url =~ /\.(gif|jpg|jpeg|mpg|mpeg|avi|mov)$/i) {
  print "Content-Type: image/gif\n";
  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($time);
  printf "Expires: %s, %02d-%s-%02d %02d:%02d:%02d GMT\n\n", $day[$wday],$mday,$month[$mon],$year,$hour,$min,$sec;
  open(GIF, "$DOCUMENT_ROOT/stop.gif");
  while (<GIF>) {
    print;
  }
  close(GIF)
} else {
  print "Content-type: text/html\n";
  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($time);
  printf "Expires: %s, %02d-%s-%02d %02d:%02d:%02d GMT\n\n", $day[$wday],$mday,$month[$mon],$year,$hour,$min,$sec;
  print "<HTML>\n\n  <HEAD>\n    <TITLE>302 Zugriff verweigert</TITLE>\n  </HEAD>\n\n";
  print "  <BODY BGCOLOR=\"#FF0000\">\n";
  if ($srcclass eq "unknown") {
    print "    <P ALIGN=CENTER>\n";
    print "    <IMG SRC=\"/stop.gif\"\n";
    print "         ALT=\"blocked\" WIDTH=\"120\" HEIGHT=\"120\" BORDER=0></A>\n </P>\n\n";
    print "    <H1 ALIGN=CENTER>Zugriff verweigert,<BR>da dieser Computer<BR>keinen Account auf dem Proxy hat.</H1>\n\n";
    print "    <TABLE BORDER=0 ALIGN=CENTER>\n";
    print "      <TR><TH ALIGN=RIGHT>&Uuml;bermittelte Information<TH ALIGN=CENTER>:<TH ALIGN=LEFT>\n";
    print "      <TR><TH ALIGN=RIGHT>Computer-Adresse<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$clientaddr\n";
    print "      <TR><TH ALIGN=RIGHT>Computer-Name<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$clientname\n";
    print "      <TR><TH ALIGN=RIGHT>Nutzeridentifikation<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$clientident\n";
    print "      <TR><TH ALIGN=RIGHT>Gruppe<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$srcclass\n";
    print "    </TABLE>\n\n";
    print "    <P ALIGN=CENTER>Falls ein Fehler vorliegt, kontaktieren Sie<BR>\n";
    print " den Administrator.</A>\n";
    print " </P>\n\n";
  } elsif ($targetclass eq "in-addr") {
    print "    <P ALIGN=CENTER>\n";
    print "    <IMG SRC=\"/stop.gif\"\n";
    print "          ALT=\"blocked\" WIDTH=\"120\" HEIGHT=\"120\" BORDER=0></A>\n      </P>\n\n";
    print "    <H1 ALIGN=CENTER>URLs mit IP-Adressen<BR>sind von diesem Rechner aus<BR>nicht erlaubt.</H1>\n\n";
    print "    <TABLE BORDER=0 ALIGN=CENTER>\n";
    print "      <TR><TH ALIGN=RIGHT>&Uuml;bermittelte Informationen<TH ALIGN=CENTER>:<TH ALIGN=LEFT>\n";
    print "      <TR><TH ALIGN=RIGHT>Computer-Adresse<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$clientaddr\n";
    print "      <TR><TH ALIGN=RIGHT>Computer Name<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$clientname\n";
    print "      <TR><TH ALIGN=RIGHT>Nutzeridentifikation<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$clientident\n";
    print "      <TR><TH ALIGN=RIGHT>Gruppe<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$srcclass\n";
    print "      <TR><TH ALIGN=RIGHT>URL<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$url\n";
    print "      <TR><TH ALIGN=RIGHT>Zielgruppe<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$targetclass\n";
    print "    </TABLE>\n\n";
    print "    <P ALIGN=CENTER>Kontaktieren Sie bitte den <B>webmaster</B> von <B>$url</B><BR>\n";
    print "      und bitten Sie ihn, dem Webserver einen g&uuml;ltigen <U>Domain Namen</U> zu geben.\n";
    print "    </P>\n\n";
  } else {
    print "    <P ALIGN=CENTER>\n";
    print "      <IMG SRC=\"/stop.gif\" ALT=\"blocked\" WIDTH=\"120\" HEIGHT=\"120\" BORDER=0></A>\n</P>\n\n";
    print "  <H1 ALIGN=CENTER>Zugriff verweigert</H1>\n\n";
    print "    <TABLE BORDER=0 ALIGN=CENTER>\n";
    print "      <TR><TH ALIGN=RIGHT>&Uuml;bermittelte Informationen<TH ALIGN=CENTER>:<TH ALIGN=LEFT>\n";
    print "      <TR><TH ALIGN=RIGHT>Computer-Adresse<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$clientaddr\n";
    print "      <TR><TH ALIGN=RIGHT>Computer-Name<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$clientname\n";
    print "      <TR><TH ALIGN=RIGHT>Nutzeridentifikation<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$clientident\n";
    print "      <TR><TH ALIGN=RIGHT>Gruppe<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$srcclass\n";
    print "      <TR><TH ALIGN=RIGHT>URL<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$url\n";
    print "      <TR><TH ALIGN=RIGHT>Zielgruppe<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$targetclass\n";
    print "    </TABLE>\n\n";
    print "    <P ALIGN=CENTER>Falls ein Fehler vorliegt, kontaktieren Sie<BR>\n";
    print "    <A HREF=mailto:mailadmin\@#DOMAIN#>den Administrator</A> und nennen Sie ihm die genannte URL.\n";
    print "    </P>\n\n";
  }  
    print " </BODY>\n\n</HTML>\n";
}
exit 0;
