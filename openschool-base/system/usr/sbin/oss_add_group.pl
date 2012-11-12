#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_group;
use oss_utils;

if( $> )
{
    die "Only root may start this programm!\n";
}

my $GROUP         ={};
my $connect       = { withIMAP => 1 };
my $oss_host      = undef;

binmode STDIN, ':utf8';
binmode STDOUT, ":utf8";

while(<STDIN>)
{
    # Clean up the line!
    chomp; s/^\s+//; s/\s+$//;
    
    my ( $key, $value ) = split / /,$_,2;

    next if( getConnect($connect,$key,$value));    

    if( $key eq "member" )
    {
           push @{$GROUP->{member}}, $value;
    }
    else
    {
          $GROUP->{$key} = $value
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
my $oss_group = oss_group->new($connect);

my $DEBUG = 0;
if( $oss_group->get_school_config('SCHOOL_DEBUG') eq 'yes' )
{
    $DEBUG = 1;
    use Data::Dumper;
}
if( defined $GROUP->{member} )
{
	foreach my $DN (@{$GROUP->{member}})
	{
	   push @{$GROUP->{memberuid}}, get_name_of_dn($DN);
	}
}
if( $DEBUG )
{
  open(OUT,">/tmp/add_group");
  print OUT Dumper($GROUP);
  close OUT; 
}

if( ! $oss_group->add($GROUP) )
{
   print Dumper($GROUP) if( $DEBUG );
   print $oss_group->{ERROR}->{code};
   print $oss_group->{ERROR}->{text};
}
if($GROUP->{web})
{
   system("/etc/init.d/apache2 reload");
}

print $oss_group->replydn($GROUP->{dn});

if( $GROUP->{grouptype} eq 'primary' && defined $GROUP->{templateuser} )
{ #we create a template user for this group
	my $tdn = $oss_group->get_entries_dn('(&(grouptype=primary)(role=templates))');
	my $TMP  = "uid t".$GROUP->{cn}."\n";
	$TMP .= "sn ".$GROUP->{description}." Template\n";
	$TMP .= "primarygroup ".get_name_of_dn($GROUP->{dn})."\n";
	$TMP .= "role templates\n";
	$TMP .= "description default\n";
	$TMP .= "userpassword ".$oss_group->{APW}."\n";
	if( $tdn->[0] )
	{
	  $TMP .= "group ".get_name_of_dn($tdn->[0])."\n";
	}
	my $TMPFILE = write_tmp_file($TMP);
	system("cat $TMPFILE | /usr/sbin/oss_add_user.pl &> /dev/null");
	system("rm $TMPFILE");
}

$oss_group->destroy();
