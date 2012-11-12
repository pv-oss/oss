#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

interface()
{
  echo "getCapabilities default start"
}

getCapabilities()
{
echo 'title Release Update of OSS
allowedRole root
allowedRole sysadmins
disabled 1
category System
order 10000'
}

default()
{
        OSSV=$( rpm -q --qf %{VERSION} openschool-base )

        if [ -e /var/adm/oss/migration ]
        then
                echo "label Die Migration läuft."
                echo "label The migration is processing."
                return
        elif [ "$OSSV" != "3.3.0" ]
        then
                echo "label Jetzt können Sie das Update von OSS 3.2 auf OSS 3.3 starten."
                echo "label Now we can start the update from OSS 3.2 to OSS 3.3"
                echo "action cancel"
                echo "action start"
                return
        elif [ -e /var/adm/oss/must-restart ]
        then
                echo "label Ihr System is auf dem aktuellen Stand. Die Migration wurde beendet.<br>Bitte starten Sie den Server neu!"
                echo "label Your system is actuall. The migration process has been comleted.<br>Please restart your server!"
        fi

}

start()
{
        at -f /usr/share/oss/tools/migrate-oss.sh now

	echo "label Die Migration wurde gestartet."
	echo "label The migration was started."

}

while read -r k v
do
    export FORM_$k=$v
done

$1
