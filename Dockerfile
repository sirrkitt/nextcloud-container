FROM alpine:3.13 AS builder
ENV	CHOST="x86_64-pc-linux-gnu"
ENV	CFLAGS="-pipe -O2 -fomit-frame-pointer"
ENV	CXXLAGS="-pipe -O2 -fomit-frame-pointer"

RUN apk add --no-cache alpine-sdk imap-dev curl-dev icu-dev postgresql-dev pcre2-dev zlib-dev libxml2-dev oniguruma-dev sqlite-dev openldap-dev libzip-dev bzip2-dev gd-dev gmp-dev libexif-dev samba-dev \
	libmemcached-dev memcached-dev autoconf imagemagick-dev freetype-dev re2c


WORKDIR	/tmp/php
RUN	wget https://www.php.net/distributions/php-8.0.2.tar.bz2 && tar xvf php-8.0.2.tar.bz2 && cd php-8.0.2 &&\
	./configure --prefix=/opt --with-config-file-path=/config/php --with-config-file-scan-dir=/config/php/conf.d \
	--disable-fpm --disable-cgi --disable-fastcgi --disable-debug --disable-phpdbg --disable-static \
	--enable-cli --enable-embed=shared --enable-shared=yes --enable-sockets --enable-pear --with-pear --enable-pcntl \
	--with-pcre-jit --enable-mbstring --enable-intl --enable-libxml --enable-simplexml --enable-bcmath \
	--with-curl --with-imap --with-imap-ssl \
	--with-ldap --with-pdo --with-pdo-mysql --with-pdo-pgsql --with-pdo-sqlite --with-sqlite \
	--with-zip --with-zlib --with-bz2 \
	--enable-ftp --with-openssl \
	--enable-gd --with-external-gd --with-jpeg --with-webp --with-gmp --with-freetype --enable-exif &&\
	make -j34 && make install

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

WORKDIR /
RUN	/opt/bin/pecl install apcu redis memcached smbclient

FROM	alpine:3.13

ENV	PUID=1010
ENV	PGID=1010

ENV	AUTOCONFIG="YES"

COPY	--from=builder /opt /opt

COPY	config.json /config/unit/config.json
COPY	extensions.ini /config/php/conf.d/extensions.ini
COPY	php.ini /config/php/php.ini

WORKDIR	/tmp
RUN	wget https://download.nextcloud.com/server/releases/nextcloud-21.0.0.tar.bz2 &&\
	tar xvf nextcloud-21.0.0.tar.bz2 &&\
	mv nextcloud /srv/nextcloud &&\
	rm nextcloud-21.0.0.tar.bz2

RUN	mkdir -p /config/unit/state

COPY	entrypoint.sh /entrypoint.sh
RUN	chmod +x /entrypoint.sh

RUN	rm -r /opt/lib/php/build && rm -r /opt/lib/php/test

RUN	apk --no-cache add openssl imap-dev pcre2-dev libxml2-dev oniguruma sqlite-libs libldap libcurl curl icu-libs libpq libzip gmp libbz2 imagemagick-libs libsmbclient libmemcached-libs ffmpeg freetype libgd

VOLUME	[ "/socket/control", "/socket/nextcloud", "/data", "/config/php", "/config/unit" ]

ENTRYPOINT ["/entrypoint.sh"]
