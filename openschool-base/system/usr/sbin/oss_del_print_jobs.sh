#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
for i in $( LANG=en_EN lpq -a | gawk '{ print $3 }' | grep -v Job )
do
     lprm $i
done
