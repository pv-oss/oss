#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2006 OpenSchoolServer Team.
# All rights reserved.
#
# Author: Peter Varkoly <peter@varkoly.de>
#
# Please send feedback to oss-support@extis.de
#
# /usr/sbin/oss_copy_file.sh
#
# Script to copy file with user rigths.
#

read who
read what
read where

su - $who -c "cp \"$what\" \"$where\"" && echo "OK"
