#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use Net::LDAP;
use Net::LDAP::Entry;
use oss_base;
use oss_utils;
binmode STDIN, ':utf8';

# Global variable
my $connect    = { withIMAP => 1 };
my $XML        = 1;
my $line       ='';
my $plugin     = '';
my $oid        = '';
my $uid        = '';
my $fquota     = '';
my $fsystem    = '';
my $quota      = '';
my $filter     = '';
my @dns        = ();
my @changes    = ();
my %SYSCONFIG  = ();

# If neccessary read the commandline options
while(my $param = shift)
{
   $XML=0 if( $param =~ /text/i );
}

while(<STDIN>)
{

   $line .= $_;

   # Clean up the line!
   chomp; s/^\s+//; s/\s+$//;

   my ( $key, $value ) = split / /,$_,2;

   next if( getConnect($connect,$key,$value));

   # The plugins have to get the original lines but not the empty lines
   if( $key ne '' )
   {
        $plugin .= $_."\n";
   }
   if( !defined $value  || $value eq  '' )
   {
      $key;
      if( $key =~ /^uniqueIdentifier=.*/i)
      {
        push @dns, $key;
      }
   }
   else
   {
      my ($attr, $val) = split / /,$value,2;
      if($attr eq 'webspace'  )
      {
        #TODO implement it!
      }
      elsif($attr eq 'adminpassword'  )
      {
        #TODO implement it!
      }
      elsif($attr =~ /^SCHOOL_/  )
      {
         $SYSCONFIG{$attr} = $val if( $key eq 'add' );
      }
      else
      {
          if( defined $val )
	  {
            push @changes, "$key" => [ "$attr" => [ "$val" ]];
          }
	  else
	  {
            push @changes, "$key" => [ "$attr" => []];
          }
      }
   }
}

# Make OSS Connection
if( defined $ENV{SUDO_USER} )
{
   if( ! defined $connect->{aDN} || ! defined $connect->{aPW} )
   {
       die "Using sudo you have to define the parameters aDN and aPW\n";
   }
}
my $oss = oss_base->new($connect);
$oss->{XML} = $XML;

if( $oss->get_school_config('SCHOOL_DEBUG') eq 'yes' )
{
  write_file("/tmp/modify_school",$line);
}


foreach my $dn ( @dns )
{
    if( -1 < $#changes )
    {
      my $mesg = $oss->{LDAP}->modify( $dn, changes=>\@changes );
      if( $mesg->code != 0 )
      {
        $oss->ldap_error($mesg);
        print STDERR $oss->{ERROR}->{text};
      }
    }
    #TODO SYSCONFIG ÄNDERUNGEN
    print $oss->reply($oss->get_school($dn));
}
#Starting the plugins
my $TMPFILE = write_tmp_file($plugin);
system("/usr/share/oss/plugins/plugin_handler.sh modify_school $TMPFILE");

$oss->destroy();

