#!/bin/sh

addgroup -S -g $PGID unit
adduser -S -h /srv/nextcloud -D -H -s /sbin/nologin -u $PUID -G unit unit

chown -R $PUID:$PGID /srv/nextcloud /data


if [ -e /socket/nextcloud/nextcloud.sock ]
then
	rm /socket/nextcloud/nextcloud.sock
fi
if [ "$AUTOCONFIG" == "YES" ]
then
	/opt/sbin/unitd
	curl --data-binary @/config/unit/config.json -X PUT --unix-socket /socket/control/control.unit.sock http://localhost/config/
	pkill unitd
fi

rm /socket/nextcloud/nextcloud.sock
exec /opt/sbin/unitd --no-daemon
