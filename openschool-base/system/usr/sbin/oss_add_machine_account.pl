#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly Nürnberg, Germany.  All rights reserved.
BEGIN{
   push @INC,"/usr/share/oss/lib/";
}
$| = 1; # do not buffer stdout

use strict;
use oss_user;
use strict;

my $name = shift;

my $oss_user  = oss_user->new({ withIMAP => 1 });
$oss_user->add( { uid           => $name.'$',
                  sn                    => "Machine account $name",
                  description           => "Machine account $name",
                  role                  => 'machine',
                  userpassword          => '{crypt}*'
                } );
$oss_user->destroy();

