#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use Data::Dumper;
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
my $fquota     = '';
my $fsystem    = '';
my $quota      = '';
my $filter     = '';
my @dns        = ();
my @changes    = ();
my @add_groups = (); 
my @del_groups = ();
my $admin      = -1; 
my $userpassword = ''; 
my $mustchange = 0;
my $sso        = 0;
my $pwmech     = 'md5';
my $ChangeCN   = 0;

# If neccessary read the commandline options
while(my $param = shift)
{
   $XML=0 if( $param =~ /text/i );
}

while(<STDIN>)
{
   $line .= $_;

   # Clean up the line!
   s/^\s+//; s/\s+$//;

   chomp;
   my ( $key, $value ) = split / /,$_,2;

   next if( getConnect($connect,$key,$value));

   # The plugins have to get the original lines but not the empty lines
   if( $key ne '' )
   {
   	$plugin .= $_."\n";
   }
   if( !defined $value  || $value eq  '' )
   {
          if( $key =~ /^uid=.*/i)
	  { 
	    push @dns, $key;
	  }
   }
   elsif($key eq 'userpassword' )
   {
	  $userpassword = $value;
   }
   elsif($key eq 'mustchange' )
   {
	if( $value =~ /yes/i )
	{
	  $mustchange = 1;
	}
   }
   elsif($key eq 'sso' )
   {
	if( $value =~ /yes/i )
	{
	  $sso = 1;
	}
   }
   elsif($key eq 'pwmech' )
   {
	  $pwmech = $value;
   }
   elsif( $key eq "quota" )
   {
          $quota = $value;
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
      if($attr eq 'group' )
      {
        push @add_groups, $val if( $key eq 'add' );
        push @del_groups, $val if( $key eq 'delete' );
      }
      elsif($attr eq 'admin' )
      {
        $admin = 1 if( $key eq 'add' );
        $admin = 0 if( $key eq 'delete' );
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
	  if( $attr eq 'cn' || $attr eq 'givenname' )
	  {
	    $ChangeCN = 1;
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
$connect->{imap} = 1;
my $oss = oss_base->new($connect);
$oss->{XML} = $XML;

if( $oss->get_school_config('SCHOOL_DEBUG') eq 'yes' )
{
  use Data::Dumper;
  $line .= Dumper(@changes);
  write_file("/tmp/modify_group",$line);
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
      else
      {
	# Updates the CN and addressBookCN to
	if( $ChangeCN )
	{
	  $oss->update_cn($dn);
	}
      }
    }
   
    if( $userpassword ne '' )
    {
	$oss->set_password($dn,$userpassword,$mustchange,$sso,$pwmech);
    } 
    #Now we make the changes in the group
    my @groups = ();
    foreach my $group (@add_groups)
    {
      $oss->add_user_to_group($dn,$group);
      push @groups, get_name_of_dn($group);
    }
    # Subscribe the new folders
    if( $#groups )
    { 
      subscribe_folders($dn,\@groups);
    }
    @groups = ();
    foreach my $group (@del_groups)
    {
      $oss->delete_user_from_group($dn,$group);
      push @groups, get_name_of_dn($group);
    }
    # Unsubscribe the folders
    if( $#groups )
    { 
      unsubscribe_folders($dn,\@groups);
    }
    #Now we make file system changes
    if( $fquota ne '' )
    {
      $oss->set_fquota($dn,$fquota,$fsystem);
    }
    
    #Now we make the mail system changes
    if( $quota ne '' )
    {
      $oss->set_quota($dn,$quota);
    }

    #Do the user change his admin status
    if( $admin != -1 )
    {
       my $SCHOOLBASE  = $oss->get_school_base($dn);
       my $DNsysadmins = $oss->get_primary_group('sysadmins',$SCHOOLBASE);
       if( $admin )
       {
         $oss->add_user_to_group($dn,$DNsysadmins);
       }
       else
       {
         $oss->delete_user_from_group($dn,$DNsysadmins);
       }
    }

    print $oss->reply({ $dn => $oss->get_user($dn)});
}
#Starting the plugins
my $TMPFILE = write_tmp_file($plugin);
system("/usr/share/oss/plugins/plugin_handler.sh modify_user $TMPFILE");

$oss->destroy();
exit;
