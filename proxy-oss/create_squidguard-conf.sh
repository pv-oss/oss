here=`pwd`
cd BL
echo "logdir /var/log/squidGuard
dbhome /var/lib/squidGuard/db
src students {
       execuserlist    ldapsearch -x '(&(role=students)(objectclass=schoolAccount))' uid | grep uid: | sed 's/uid: //'
       log             students
}

src sysadmins {
       execuserlist    ldapsearch -x '(&(role=*sysadmins)(objectclass=schoolAccount))' uid | grep uid: | sed 's/uid: //'
       log             administration
}

src teachers {
       execuserlist    ldapsearch -x '(&(role=teachers)(objectclass=schoolAccount))' uid | grep uid: | sed 's/uid: //'
       log             teachers
}

src administration {
       execuserlist    ldapsearch -x '(&(role=administration)(objectclass=schoolAccount))' uid | grep uid: | sed 's/uid: //'
       log             administration
}

dest good {
    domainlist custom/good/domains
}

dest bad {
    domainlist custom/bad/domains
    log bad.log
}

"

for i in `grep 'NAME:' global_usage  | gawk '{ print $2 }'`;
do
   j=`echo $i | sed s#/#-#`
   echo "dest $j {";
   test -e $i/domains && echo "     domainlist BL/$i/domains";
   test -e $i/urls    && echo "     urllist    BL/$i/urls";
                         echo "     log        $j.log";
   echo "}";
   echo;
   ACLS="$ACLS !$j"
done

echo "acl {
	students {
		pass good !bad !in-addr $ACLS all
		redirect 302:http://admin/cgi-bin/oss-stop.cgi/?clientaddr=%a&clientname=%n&clientident=%i&srcclass=%s&targetclass=%t&url=%u
	}
	sysadmins {
		pass good !bad $ACLS all
		redirect 302:http://admin/cgi-bin/oss-stop.cgi/?clientaddr=%a&clientname=%n&clientident=%i&srcclass=%s&targetclass=%t&url=%u
	}
	teachers {
		pass good !bad $ACLS all
		redirect 302:http://admin/cgi-bin/oss-stop.cgi/?clientaddr=%a&clientname=%n&clientident=%i&srcclass=%s&targetclass=%t&url=%u
	}
	administration {
		pass good !bad $ACLS all
		redirect 302:http://admin/cgi-bin/oss-stop.cgi/?clientaddr=%a&clientname=%n&clientident=%i&srcclass=%s&targetclass=%t&url=%u
	}
	default {
		pass good !bad $ACLS all
		redirect 302:http://admin/cgi-bin/oss-stop.cgi/?clientaddr=%a&clientname=%n&clientident=%i&srcclass=%s&targetclass=%t&url=%u
	}
	
}"

cd $here
