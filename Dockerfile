FROM alpine:3.6

# Install common packages
RUN apk add --update \
        bash \
        ca-certificates \
        curl \
        wget \
        unzip \
        psmisc \
        vim \
        && \
    # Clear cache data
    rm -rf /var/cache/apk/* /tmp/*

# Install s6-overlay
# (https://github.com/just-containers/s6-overlay)
ENV S6_OVERLAY_VER 1.20.0.0
RUN wget -qO- https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VER}/s6-overlay-amd64.tar.gz | tar xz -C /

# Install consul-template
# (https://github.com/hashicorp/consul-template)
ENV CT_VER 0.11.0
RUN wget -q -O /tmp/ct.zip https://releases.hashicorp.com/consul-template/${CT_VER}/consul-template_${CT_VER}_linux_amd64.zip && \
    unzip /tmp/ct.zip -d /usr/local/bin/ && \
    chmod +x /usr/local/bin/consul-template && \
    rm -f /tmp/ct.zip

# -----------
# -- Nginx --
# -----------
ENV NGX_VER="1.11.10"
ENV NGX_PLUGIN_HEADERS_MORE_VER="0.32"
ENV NGX_PLUGIN_VTS_VER="0.1.15"

RUN \
    # Prepare build tools for compiling nginx from source code
    apk --update add openssl-dev pcre-dev zlib-dev build-base autoconf libtool && \

    # Download nginx source
    wget -qO- http://nginx.org/download/nginx-${NGX_VER}.tar.gz | tar xz -C /tmp/

RUN \
    # Download nginx plugins
    wget -qO- https://github.com/openresty/headers-more-nginx-module/archive/v${NGX_PLUGIN_HEADERS_MORE_VER}.tar.gz | tar xz -C /tmp/ && \
    wget -qO- https://github.com/vozlt/nginx-module-vts/archive/v${NGX_PLUGIN_VTS_VER}.tar.gz | tar xz -C /tmp/

RUN \
    # Build and install nginx
    cd /tmp/nginx-${NGX_VER} && \
    ./configure --prefix=/usr/share/nginx \
                --sbin-path=/usr/sbin/nginx \
                --conf-path=/etc/nginx/nginx.conf \
                --error-log-path=/var/log/nginx/error.log \
                --http-log-path=/var/log/nginx/access.log \
                --pid-path=/var/run/nginx.pid \
                --lock-path=/var/run/nginx.lock \
                --http-client-body-temp-path=/var/lib/nginx/tmp/client_body \
                --http-proxy-temp-path=/var/lib/nginx/tmp/proxy \
                --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi \
                --http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi \
                --http-scgi-temp-path=/var/lib/nginx/tmp/scgi \
                --user=nginx \
                --group=nginx \
                --with-http_ssl_module \
                --with-http_realip_module \
                --with-http_gunzip_module \
                --with-http_gzip_static_module \
                --with-http_auth_request_module \
                --with-http_stub_status_module \
                --add-module=/tmp/headers-more-nginx-module-${NGX_PLUGIN_HEADERS_MORE_VER} \
                --add-module=/tmp/nginx-module-vts-${NGX_PLUGIN_VTS_VER} \
                --with-threads \
                --with-ld-opt="-Wl,-rpath,/usr/lib/" && \
    make -j2 && \
    make install && \
    rm -fr /tmp/nginx-${NGX_VER} && \

    # Remove the build tool
    apk del openssl-dev pcre-dev zlib-dev build-base autoconf libtool

RUN \
    # Install the required librairies
    apk add --update libssl1.0 libcrypto1.0 pcre zlib && \

    # Create 'nginx' user and the directories declared in the configure step
    addgroup -S -g 101 nginx && adduser -HS -u 100 -h /var/www/localhost/htdocs -s /sbin/nologin -G nginx nginx && \
    mkdir -p /var/lib/nginx/tmp && \
    chmod 755 /var/lib/nginx && \
    chmod -R 777 /var/lib/nginx/tmp && \
    mkdir -p /var/cache/nginx && \
    chmod 755 /var/cache/nginx
    
# Copy all the rootfs dir into the container
COPY rootfs /
RUN chmod +x /scripts/*
RUN echo ""  > /usr/share/nginx/html/index.html

CMD ["/scripts/init.sh"]
EXPOSE 80

ENV CONTAINER_VERSION 2017102001