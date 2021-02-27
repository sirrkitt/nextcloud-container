FROM alpine:3.13 AS builder

#ENV	CFLAGS="-pipe -O2 -fomit-frame-pointer -fstack-protector-strong -fpic -fpie -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
#ENV	CXXLAGS="-pipe -O2 -fomit-frame-pointer -fstack-protector-strong -fpic -fpie -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
#ENV	LDFLAGS="-Wl,-O1 -pie -fpic"
ENV	CFLAGS="-pipe -O2 -fomit-frame-pointer -fstack-protector-strong -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
ENV	CXXLAGS="-pipe -O2 -fomit-frame-pointer -fstack-protector-strong -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
#ENV	LD_LIBRARY_PATH="/opt/lib"

#ENV	LDFLAGS="-Wl,-O1"

RUN apk add --no-cache alpine-sdk autoconf bison re2c libevent-dev \
	imap-dev curl-dev icu-dev postgresql-dev pcre2-dev zlib-dev libxml2-dev oniguruma-dev sqlite-dev openldap-dev libzip-dev bzip2-dev gd-dev gmp-dev libexif-dev samba-dev \
	libmemcached-dev memcached-dev imagemagick-dev freetype-dev libjpeg-turbo-dev libmcrypt-dev \
	libpng-dev pcre-dev libwebp-dev libsodium-dev argon2-dev libffi-dev libintl musl-libintl


WORKDIR	/tmp/php
RUN	wget https://www.php.net/distributions/php-8.0.2.tar.bz2 && tar xvf php-8.0.2.tar.bz2 && cd php-8.0.2 &&\
	./configure --prefix=/opt --with-config-file-path=/config/php \
	--with-config-file-scan-dir=/config/php/conf.d --disable-short-tags \
	--disable-fpm --disable-cgi --disable-debug --disable-static \
	--enable-cli --enable-embed=shared --enable-shared=yes --enable-sockets --enable-pcntl=shared \
	--enable-option-checking=fatal --with-pic --without-pear \
	--with-pcre-jit --enable-mbstring=shared --enable-intl=shared --enable-simplexml --enable-bcmath=shared \
	--with-curl=shared --with-imap=shared --with-imap-ssl --enable-mysqlnd=shared \
	--with-ldap=shared --with-pdo-mysql=shared,mysqlnd --with-pdo-pgsql=shared --with-pdo-sqlite=shared \
	--with-bz2=shared --enable-calendar=shared \
	--enable-ftp=shared --with-openssl=shared --with-system-ciphers --enable-ctype=shared \
	--enable-dom=shared --enable-fileinfo=shared --enable-posix=shared \
	--with-sodium=shared --with-password-argon2 --with-libedit --enable-session=shared \
	--enable-gd=shared --with-external-gd --with-jpeg --with-webp --with-xpm --with-gmp --with-freetype --enable-exif=shared --disable-gd-jis-conv \
	--with-ffi=shared --with-gettext=shared --enable-opcache=shared --enable-simplexml=shared \
	--with-sqlite3=shared --enable-xml=shared --enable-xmlreader=shared --enable-xmlwriter=shared \
	--with-zip=shared --with-zlib --without-readline --with-layout=GNU && \
	make -j34 && make install
	#--disable-phpdbg

WORKDIR /tmp/unit
RUN	wget https://unit.nginx.org/download/unit-1.22.0.tar.gz && tar xvf unit-1.22.0.tar.gz && cd unit-1.22.0 &&\
	./configure --prefix=/opt --openssl --control=unix:/socket/control/control.unit.sock --log=/dev/stdout --state=/config/unit/state --pid=/run/unit.pid --user=unit --group=unit &&\
	make -j32 && make install &&\
	./configure php --config=/opt/bin/php-config --lib-path=/opt/lib/ --module=php &&\
	make php -j32 && make php-install

WORKDIR /tmp/imagick
RUN	git clone https://github.com/Imagick/imagick . &&\
	/opt/bin/phpize && ./configure --with-php-config=/opt/bin/php-config &&\
	make && make install

WORKDIR /tmp/apcu
RUN	wget https://pecl.php.net/get/apcu-5.1.19.tgz && tar xvf apcu*.tgz && mv apcu*/* . && \
	/opt/bin/phpize && ./configure --with-php-config=/opt/bin/php-config && \
	make && make install

WORKDIR /tmp/redis
RUN	wget https://pecl.php.net/get/redis-5.3.3.tgz && tar xvf redis*.tgz && mv redis*/* . && \
	/opt/bin/phpize && ./configure --with-php-config=/opt/bin/php-config && \
	make && make install

WORKDIR /tmp/memcached
RUN	wget https://pecl.php.net/get/memcached-3.1.5.tgz && tar xvf memcached* && mv memcached*/* . && \
	/opt/bin/phpize && ./configure --with-php-config=/opt/bin/php-config && \
	make && make install

WORKDIR /tmp/smbclient
RUN	wget https://pecl.php.net/get/smbclient-1.0.5.tgz && tar xvf smbclient*.tgz && mv smbclient*/* . && \
	/opt/bin/phpize && ./configure --with-php-config=/opt/bin/php-config && \
	make && make install

FROM	alpine:3.13

ENV	PUID=1010
ENV	PGID=1010
ENV	AUTOCONFIG="YES"
ENV	DEFCONFIG="YES"

COPY	--from=builder /opt /opt

WORKDIR	/tmp
RUN	wget https://download.nextcloud.com/server/releases/nextcloud-21.0.0.tar.bz2 &&\
	tar xvf nextcloud-21.0.0.tar.bz2 &&\
	mv nextcloud /srv/nextcloud &&\
	rm nextcloud-21.0.0.tar.bz2 &&\
	mkdir -p /config/nextcloud /config/php /config/unit /config/php/conf.d /config/unit/state \
		/data /data/nextcloud /data/custom_apps /socket /socket/control /socket/nextcloud \
		/default /default/nextcloud-config &&\
	cp -R /srv/nextcloud/config /default/nextcloud-config &&\
	find /srv/nextcloud/ -type d -exec chmod 750 {} \; &&\
	find /srv/nextcloud/ -type f -exec chmod 640 {} \;
WORKDIR /	
RUN	rm -r /opt/lib/php/build

RUN	apk --no-cache add openssl imap-dev pcre2-dev libxml2-dev oniguruma sqlite-libs libldap \
	libcurl curl icu-libs libpq libzip gmp libbz2 imagemagick-libs libsmbclient \
	libmemcached-libs ffmpeg freetype libgd libsodium argon2-libs libffi

COPY	config.json /default/unit.config.json
COPY	extensions.ini /default/php.extensions.ini
COPY	php.ini /default/php.ini
COPY	entrypoint.sh /entrypoint.sh
RUN	chmod +x /entrypoint.sh


VOLUME	[ "/socket/control", "/socket/nextcloud", "/data/nextcloud", "/config", "/srv/nextcloud/custom_apps", "/srv/nextcloud/config", "/srv/nextcloud/custom_theme" ]

ENTRYPOINT ["/entrypoint.sh"]
