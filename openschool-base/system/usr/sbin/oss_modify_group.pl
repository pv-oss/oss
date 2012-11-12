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
my $oid        = '';
my $uid        = '';
my $fquota     = '';
my $fsystem    = '';
my $quota      = '';
my $filter     = '';
my $plugin     = '';
my @dns        = ();
my @changes    = ();
my @add_user   = (); 
my @del_user   = (); 
my @mboxacls   = (); 

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
          chomp $key;
	  if( $key ne '' )
	  {
            push @dns, $key;
	  }  
   }
   elsif( $key eq "quota" )
   {
          $quota = $value;
   }
   elsif( $key eq "mboxacl" )
   {
	  push @mboxacls, "$value";
   }
   elsif( $key eq "fquota" )
   {
          ($fquota,$fsystem) = split / /,$value;
          if($fsystem eq '' )
	  {
            $fsystem = '-a';
          }
   }
   else
   {
      my ($attr, $val) = split / /,$value,2;
      if($attr eq 'member' )
      {
        push @add_user, $val if( $key eq 'add' );
        push @del_user, $val if( $key eq 'delete' );
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
  write_file("/tmp/modify_group",$line);
}



foreach my $dn ( @dns )
{
    if( -1 < $#changes ) {
      my $mesg = $oss->{LDAP}->modify( $dn, changes=>\@changes );
      if( $mesg->code != 0 )
      {
        $oss->ldap_error($mesg);
        print STDERR $oss->{ERROR}->{text};
      }
    }
    #Now we change the members:
    foreach my $member ( @add_user )
    {
      $oss->add_user_to_group( $member, $dn);
    }
    foreach my $member ( @del_user )
    {
      $oss->delete_user_from_group( $member, $dn);
    }
    
    #Now we make file system changes
    if( $fquota ne '' )
    {
      $fquota *= 1024;
      my $gidnumber = $oss->get_attribute($dn,'gidnumber');
      system("/usr/sbin/setquota -g $gidnumber $fquota $fquota 0 0 $fsystem");
    }
    
    #Now we make the mail system changes
    if( $quota ne '' )
    {
      my $cn = get_name_of_dn($dn);
      my @qarray = (); 
    
      if( $quota )
      {
        @qarray = ("STORAGE", $quota * 1024 );
      }
      $oss->{IMAP}->setquota($cn, @qarray);
    }

    #Now we modify the mailbox acls if neccesary
    foreach( @mboxacls )
    {
    	my( $owner,$acl ) = split / /,$_;
        $oss->set_mbox_acl($dn,$owner,$acl );
    }

}
#Starting the plugins
my $TMPFILE = write_tmp_file($plugin);
system("/usr/share/oss/plugins/plugin_handler.sh modify_group $TMPFILE");
$oss->destroy();
exit;
