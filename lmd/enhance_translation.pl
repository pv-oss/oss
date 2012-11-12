#!/usr/bin/perl
#
# Copyright (c) 2007 - 2009  Peter Varkoly <peter@varkoly.de>, Fürth.  All rights reserved.
#
# $Id: lmd.pl pv Exp $
#
#
use strict;
use Config::IniFiles;
use DBI;
use utf8;
use open ':utf8';
binmode STOUT, ':utf8';

my $MYSQLPW  = `gawk 'FS="="{ if(/password/) print \$2 }' /root/.my.cnf`;
chomp $MYSQLPW;
my $value;

#Initialize the translations
my $DBH = DBI->connect( 'dbi:mysql:lmd', 'root', $MYSQLPW);
$DBH->do("SET CHARACTER SET utf8");
$DBH->do("SET NAMES utf8");
$DBH->do("DELETE from lang");
foreach my $f ( glob("/usr/share/lmd/lang/*ini") )
{
        if( $f =~ /\/usr\/share\/lmd\/lang\/base_(.*)\.ini/ )
        {
                my $lang = $1;
                my $m = new Config::IniFiles( -file => $f );
                if( $m )
                {
			my $sel  = $DBH->prepare("SELECT section,string,value FROM missedlang WHERE lang='$lang'");
			$sel->execute;
			while( $value = $sel->fetch() )
			{
				print "correcture of: ".$value->[0].' -> '.$value->[1].' = '.$value->[2]."\n";
				if( $value->[2] ne '' )
				{
					if( $m->val($value->[0],$value->[1] ) )
					{
						$m->setval($value->[0],$value->[1],$value->[2]);
					}
					else
					{
						$m->newval($value->[0],$value->[1],$value->[2]);
					}
				}
			}
			$m->WriteConfig("$f.enhanced");

                }
                else
                {
                        print STDERR "ERROR can not read $f\n";
                }
        }
}
$DBH->disconnect;

