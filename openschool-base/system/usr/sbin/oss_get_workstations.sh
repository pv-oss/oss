#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
case "$1" in
	--online)
		filter='(&(objectclass=schoolWorkstation)(cValue=STATE=on))'
		;;
	--offline)
		filter='(&(objectclass=schoolWorkstation)(cValue=STATE=off))'
		;;
	--help)
		echo "Usage: $0 {|--online|--offline|--help}"
		exit
        	;;
  	*)
	filter='(&(objectclass=dhcpEntry)(objectclass=schoolWorkstation))'
esac

for i in `ldapsearch -x -LLL $filter cn | grep cn: | sed 's/cn: //' | sort`
do
   echo $i `host $i | awk '{ print $4 }'`
done 
