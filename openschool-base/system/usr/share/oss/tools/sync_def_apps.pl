#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2008 Peter Varkoly Fuerth, Germany.  All rights reserved
# <peter@varkoly.de>

BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_utils;
use oss_base;
use DBI;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/sync_def_apps.pl [OPTION]'."\n".
		'Leiras ....'."\n\n".
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
		'	sync_def_apps.pl'."\n".
		'DESCRIPTION:'."\n".
		'	Leiras ...'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"		                  : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h, --help        : Display this help.(type=boolean)'."\n".
		'		-d, --description : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}

my $oss    = oss_base->new();
my $mpw    = `gawk 'FS="="{ if(/password=/) print \$2 }' /root/.my.cnf`;
my $mhost  = `gawk 'FS="="{ if(/host=/) print \$2 }' /root/.my.cnf`;
chomp $mpw;

my @APPS    = split /,/,$oss->{SYSCONFIG}->{SCHOOL_EGW_APPLICATIONS};
my @ST_APPS = split /,/,$oss->{SYSCONFIG}->{SCHOOL_EGW_STUDENT_APPLICATIONS};

my $result = $oss->{LDAP}->search(
                base   => $oss->{SYSCONFIG}->{GROUP_BASE},
                filter => 'groupType=primary',
                scope  => 'one',
                attr   => ['gidnumber','role']
        );

my $dbh = DBI->connect( 'dbi:mysql:egroupware;host='.$mhost, 'root', $mpw) or die $DBI::errstr;
foreach my $entry ($result->all_entries)
{
    my $role = $entry->get_value('role');
    my $gid  = $entry->get_value('gidnumber');
    next if( $role eq 'templates');
    next if( $role eq 'workstations');
    # First we clean up
    $dbh->do("delete from egw_acl where acl_appname!=\'phpgw_group\' AND acl_location=\'run\' AND acl_account=-$gid");
    if( $role eq 'students' )
    {
        foreach my $app (@ST_APPS)
        {
            #print "INSERT INTO egw_acl VALUES ('$app','run',-$gid,1);\n";
            $dbh->do("INSERT INTO egw_acl VALUES ('$app','run',-$gid,1)");
        }
    }
    else
    {
        foreach my $app (@APPS)
        {
            #print "INSERT INTO egw_acl VALUES ('$app','run',-$gid,1);\n";
            $dbh->do("INSERT INTO egw_acl VALUES ('$app','run',-$gid,1)");
        }
    }
}
$dbh->disconnect;

