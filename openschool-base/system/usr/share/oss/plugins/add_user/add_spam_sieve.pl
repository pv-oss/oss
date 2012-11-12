#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2005 Peter Varkoly Fuerth, Germany.  All rights reserved
# <peter@varkoly.de>
# Revision: $Rev: 1618 $

BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

$| = 1; # do not buffer stdout

use strict;
use oss_utils;
use oss_base;
use ManageSieve;

my $oss         = oss_base->new({withIMAP=>1});
my $uid         = "";
my $mailenabled = "";
my $role        = "";

while(<STDIN>)
{
  my ( $key, $value ) = split / /,$_,2;
  chomp $value; $key = lc( $key );
  if ( $key eq 'uid' )
  {
    $uid = $value;
  }
  elsif ( $key eq 'mailenabled' )
  {
     $mailenabled = lc($value);
  }
  elsif ( $key eq 'role' )
  {
     $role = lc($value);
  }
}

if ( $mailenabled eq 'no' || $role eq 'machine' || $role eq 'workstations' )
{
  exit;
}
my $spam = 'require ["envelope", "fileinto", "reject", "vacation", "regex"] ;

 if header :is "X-Spam-Flag" ["YES"]

 {
    fileinto "Spam";

 }
';
$oss->connect_sieve($uid);
$oss->{IMAP}->create("user/$uid/Spam");
my ($res, $text) = $oss->{SIEVE}->putScript('spam',$spam);
print "$res,$text\n";
$oss->{SIEVE}->setActive('spam');

$oss->destroy();

