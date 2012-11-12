#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
if [ "$1" = "-e" ]
then
   EXPORT_ONLY=1
fi
if [ "$1" = "-i" ]
then
   IMPORT_ONLY=1
fi
if [ "$1" = "-h" ]
then
    echo "
Usage $0 [ -ieh ]
    -i	Clear only Import directories
    -e  Clear only Export directories
    -h  Print this page
"
    exit
fi

if [ ! -d /home/students ]
then
   echo "/home/students does not exists"
   exit
fi

cd /home/students
for i in *
do
    if [ -z "$IMPORT_ONLY" ]
    then
	rm -rf $i/Export
	mkdir  $i/Export
	chown $i:students $i/Export
    fi
    if [ -z "$EXPORT_ONLY" ]
    then
        rm -rf $i/Import
        mkdir  $i/Import
        chown $i:students $i/Import
    fi
done
