FROM combro2k/debian-debootstrap:8
MAINTAINER Martijn van Maurik <docker@vmaurik.nl>

ENV DOCKER_HOST unix:///tmp/docker.sock
ENV NGINX_VERSION 1.9.5
ENV MODULESDIR /usr/src/nginx-modules
ENV NPS_VERSION 1.9.32.10
ENV DOCKER_GEN 0.4.2
ENV DEBIAN_FRONTEND noninteractive

EXPOSE 80 443

# Install Nginx.
RUN apt-get update && apt-get install nano git build-essential cmake zlib1g-dev libpcre3 libpcre3-dev unzip wget curl tar libpthread-stubs0-dev:amd64 -y && \
    apt-get clean && \
    rm -fr /var/lib/apt

RUN mkdir -p ${MODULESDIR} && \
    mkdir -p /data/{config,ssl,logs} && \
    cd /usr/src/ && wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && tar xf nginx-${NGINX_VERSION}.tar.gz && rm -f nginx-${NGINX_VERSION}.tar.gz && \
    cd /usr/src/ && git clone https://boringssl.googlesource.com/boringssl && \
    cd ${MODULESDIR} && git clone git://github.com/bpaquet/ngx_http_enhanced_memcached_module.git && \
    cd ${MODULESDIR} && git clone https://github.com/openresty/headers-more-nginx-module.git

ADD nginx.patch /usr/src/nginx.patch

# BoringSSL specifics
RUN cd /usr/local && curl https://storage.googleapis.com/golang/go1.4.2.linux-amd64.tar.gz | tar zxv && \
    cd /usr/src/ && cd /usr/src/boringssl && \
    mkdir build && cd build && PATH=${PATH}:/usr/local/go/bin cmake ../ && make && cd .. && \
    cd /usr/src/boringssl && mkdir -p .openssl/lib && cd .openssl && ln -s ../include && cd .. && \
    cd /usr/src/boringssl && cp build/crypto/libcrypto.a build/ssl/libssl.a .openssl/lib && \
    cd ${MODULESDIR} && \
    wget --no-check-certificate https://github.com/pagespeed/ngx_pagespeed/archive/release-${NPS_VERSION}-beta.zip && \
    unzip release-${NPS_VERSION}-beta.zip && \
    cd ngx_pagespeed-release-${NPS_VERSION}-beta/ && \
    wget --no-check-certificate https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz && \
    tar -xzvf ${NPS_VERSION}.tar.gz && \
    cd /usr/src/nginx-${NGINX_VERSION} && patch -p1 < ../nginx.patch && ./configure \
	--prefix=/etc/nginx \
	--sbin-path=/usr/sbin/nginx \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=/data/logs/error.log \
	--http-log-path=/data/logs/access.log \
	--pid-path=/var/run/nginx.pid \
	--lock-path=/var/run/nginx.lock \
	--with-http_realip_module \
	--with-http_addition_module \
	--with-http_sub_module \
	--with-http_dav_module \
	--with-http_flv_module \
	--with-http_mp4_module \
	--with-http_gunzip_module \
	--with-http_gzip_static_module \
	--with-http_random_index_module \
	--with-http_secure_link_module \
	--with-http_stub_status_module \
	--with-file-aio \
	--with-ipv6 \
	--with-http_ssl_module \
        --with-http_v2_module \
        --with-openssl=../boringssl \
	--add-module=${MODULESDIR}/ngx_pagespeed-release-${NPS_VERSION}-beta \
	--add-module=${MODULESDIR}/ngx_http_enhanced_memcached_module \
	--add-module=${MODULESDIR}/headers-more-nginx-module && \
    cd /usr/src/nginx-${NGINX_VERSION} && make && make install

#Add custom nginx.conf file
ADD nginx.conf /etc/nginx/nginx.conf
ADD pagespeed.conf /etc/nginx/pagespeed.conf
ADD proxy_params /etc/nginx/proxy_params

RUN mkdir /app
WORKDIR /app
ADD ./app /app

RUN wget -P /usr/local/bin https://godist.herokuapp.com/projects/ddollar/forego/releases/current/linux-amd64/forego && \
    chmod u+x /usr/local/bin/forego && \
    chmod u+x /app/init.sh && \
    curl -L -k https://github.com/jwilder/docker-gen/releases/download/${DOCKER_GEN}/docker-gen-linux-amd64-${DOCKER_GEN}.tar.gz | tar zxv

CMD ["/app/init.sh"]
