# LMD ManageStudents modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/","/usr/share/lmd/alibs/"; }

package ManageStudents;

use strict;
#use oss_user;
use EditUser;
use vars qw(@ISA);
#@ISA = qw(oss_user EditUser);
@ISA = qw(EditUser);

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
#    my $self    = oss_user->new($connect);
    my $self    = EditUser->new($connect);
    $self->{ManageStudents} = 1;
    return bless $self, $this;
}

1;
