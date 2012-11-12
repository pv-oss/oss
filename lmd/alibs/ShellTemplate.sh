#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

interface()
{
  echo "getCapabilities default search"
}

getCapabilities()
{
echo 'title Search installed Packages
allowedRole root
allowedRole sysadmins
category System
order 1
variable filter    [ type => "string" , label=>"Search Filter for Packages" ]
variable packages  [ type => "text"   , label=>"Found Packages" ]
variable testpop   [ type => "popup"  , label=>"Test Popup" ]
variable testlpop  [ type => "popup"  , label=>"Test Labeled Popup" ]'
}

default()
{
packages=`rpm -qa "$FORM_filter" | sort | base64 -w0`
#packages=`rpm -qa "aaa*" | sort | base64 -w0`
echo "filter *
packages #BASE64#$packages
testpop  1
testpop  2
testpop  3
testpop  4
testpop  #DEFAULT#1
testlpop #LABEL#Egy
testlpop #VALUE#1
testlpop #LABEL#Kettö
testlpop #VALUE#2
testlpop #LABEL#Három
testlpop #VALUE#3
testlpop #LABEL#Négy
testlpop #VALUE#4
testlpop #DEFAULT#4
LINE line1
var1 value1
var2 value2
testpop  1
testpop  2
testpop  3
testpop  4
testpop  #DEFAULT#1
ENDLINE
TABLE table1
LINE line1
var1 value1
var2 value2
ENDLINE
LINE line2
var1 value1
var2 value2
ENDLINE
ENDTABLE
action search"
}

search()
{
   default;
}


while read -r k v
do
    export FORM_$k=$v
done

$1
