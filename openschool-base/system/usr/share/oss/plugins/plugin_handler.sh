#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# (c) 2011 EXTIS GmbH
# Revision: $Rev: 1618 $

. /etc/sysconfig/schoolserver
what=$1
conf=$2

if test -z "$what"
then
  echo "Usage: $@ action configfile"
  exit
fi

if [ "$SCHOOL_DEBUG" = "yes" ]
then
  cp $conf $conf.DEBUG
fi

if [ -d /usr/share/oss/plugins/$what ]
then
 cd /usr/share/oss/plugins/$what
 for i in `find -mindepth 1 -maxdepth 1` 
 do
   cat $conf | /usr/share/oss/plugins/$what/$i
   if [ "$SCHOOL_DEBUG" = "yes" ]
   then
     echo "cat $conf | /usr/share/oss/plugins/$what/$i" >> $conf.DEBUG
   fi
 done
fi 

rm $conf
