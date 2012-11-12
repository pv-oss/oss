#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2005 Peter Varkoly Fuerth, Germany.  All rights reserved.
# Copyright (c) 2002 SuSE Linux AG Nuernberg, Germany.  All rights reserved.
#
# $Id: clear_home,v 2.1 2005/12/23 11:39:09 pv Exp $
#
GIDNOG=65534
HOME=/home/workstations/$1
PROFIL=/home/profile/$1
SKEL=/etc/skel

if test -e $HOME;
then
  #Clean directory
  rm -r $HOME   &> /dev/null
fi
if test -e $PROFIL;
then
  #Clean directory
  rm -r $PROFIL &> /dev/null
fi

#Create home directory
if test -d /home/templates/tworkstations
then
   SKEL=/home/templates/tworkstations
fi
rsync   -a --delete  $SKEL/  $HOME/
chown   -R $2:$3 $HOME
chmod   770      $HOME

#Create profile directory
if test -e /home/profile/tworkstations
then
  cp -a /home/profile/tworkstations $PROFIL
  chmod 700 $PROFIL
else
  mkdir   -m 700       $PROFIL
fi
chown   -R $2:$GIDNOG  $PROFIL
setfacl -d -m u::rwx   $PROFIL

