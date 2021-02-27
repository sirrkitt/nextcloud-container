#!/bin/sh

addgroup -S -g $PGID unit
adduser -S -h /srv/nextcloud -D -H -s /sbin/nologin -u $PUID -G unit unit

chown -R $PUID:$PGID /srv/nextcloud /data

if [ ! -d "/config/unit/state" ]
then
	mkdir -p /config/unit/state
fi

if [ "$DEFCONFIG" == "YES" ]
then
	[ ! -e /config/unit/config.json ] && cp /default/unit.config.json /config/unit/config.json
	[ ! -e /config/php/conf.d/extensions.ini ] && cp /default/php.extensions.ini /config/php/conf.d/extensions.ini
	[ ! -e /config/php/php.ini ] && cp /default/php.ini /config/php/php.ini
fi

if [ "$AUTOCONFIG" == "YES" ]
then
	if [ -e /socket/nextcloud/nextcloud.sock ]
	then
		rm /socket/nextcloud/nextcloud.sock
	fi
	/opt/sbin/unitd
	curl --data-binary @/config/unit/config.json -X PUT --unix-socket /socket/control/control.unit.sock http://localhost/config/
	pkill unitd
fi

if [ -e /socket/nextcloud/nextcloud.sock ]
then
	rm /socket/nextcloud/nextcloud.sock
fi

echo "Settings permissions"
	chown root:root /config/unit/state
	chmod 700 /config/unit/state
	chown -R unit:unit /srv/nextcloud /data
	find /data/ -type d -exec chmod 750 {} \;
	find /data/ -type f -exec chmod 640 {} \;

echo "Starting unitd"
	exec /opt/sbin/unitd --no-daemon
