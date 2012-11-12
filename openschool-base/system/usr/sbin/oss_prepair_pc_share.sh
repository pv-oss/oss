#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
if [ ! -d /home/workstations/$1 ]
then
  mkdir /home/workstations/$1
fi
chmod 755    /home/workstations/
chmod -R 777 /home/workstations/$1
