#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
FILE=$1
DATE=`/usr/share/oss/tools/oss_date.sh`
if [ -e $FILE ]
then
   cp $FILE $FILE.$DATE
fi
if [ $2 ]
then
   cp $FILE.$2 $FILE
fi
