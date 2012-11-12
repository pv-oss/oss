#!/usr/bin/perl  -U
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2006 Peter Varkoly Fuerth, Germany.  All rights reserved
# <peter@varkoly.de>
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}
$| = 1; # do not buffer stdout

use strict;
use Net::LDAP;
use oss_base;


# Open an LDAP connection
my $oss = oss_base->new({ aDN => 'anon' });

my $DEBUG               = 0;
if( $oss->get_school_config('SCHOOL_DEBUG') eq 'yes' )
{
  $DEBUG = 1;
}
open(LOG,">/var/log/squid/$$.log") if ($DEBUG);

while(<>)
{
  chomp;
  my $ip   = $_;
  my $result = $oss->{LDAP}->search( base   => 'ou=people,'.$oss->{LDAP_BASE},
                              filter => "(configurationValue=LOGGED_ON=$ip)",
                              scope  => 'one',
                              attr   => ['internetDisabled','uid']
              );
  if( $result->code() )
  {
      $oss = oss_base->new({ aDN => 'anon' });
      $result = $oss->{LDAP}->search( base   => 'ou=people,'.$oss->{LDAP_BASE},
                              filter => "(configurationValue=LOGGED_ON=$ip)",
                              scope  => 'one',
                              attr   => ['internetDisabled','uid']
              );

  }
  if( $result->count() eq 0 )
  {
      my $host     = $oss->get_workstation($ip);
      if( defined $host ) {
          my $user = $oss->get_config_value( $host, 'LOGGED_ON' );
          if( defined $user )
          {
          	print "OK user=\"$user\"\n";
          	next;
          }
      }

    print "ERR user=No user logged on on $ip\n";
    next;
  }
  my $user = $result->entry(0)->get_value('uid');
  if( defined $result->entry(0)->get_value('internetDisabled') &&
              $result->entry(0)->get_value('internetDisabled') eq 'yes' )
  {
    print "ERR user=\"$user\" is not allowed to surf\n";
    next;
  }
  print "OK user=\"$user\"\n";
}
$oss->destroy();
close(LOG) if ($DEBUG);

