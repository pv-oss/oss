#!/bin/sh

# Script zum Erzeugen der Datenbankdateien aus den domain und url Dateien.
# Muss nach jedem Einspielen der shalla-Listen gemacht werden, da diese
# immer komplett neu geladen werden und nicht als diff vorliegen.
#
# Thomas Litsch <tl@extis.de>, 24.04.2008
# Peter Varkoly <pv@extis.de>, 28.05.2008
#
# Nachsehen, ob die Listen schon da sind, und runterladen

/bin/tar xzvf /var/lib/squidGuard/db/shallalist.tar.gz -C /var/lib/squidGuard/db &> /var/log/shallainit.log

/usr/sbin/rcsquid stop

# Jetzt die Datenbank neu aufbauen lassen
/usr/sbin/squidGuard -d -c /etc/squid/squidguard.conf -C all  >> /var/log/shallainit.log
/bin/chown -R squid:nogroup /var/lib/squidGuard/
/bin/chown -R squid:nogroup /var/log/squidGuard/

/usr/sbin/rcsquid start

exit 0


                                                
