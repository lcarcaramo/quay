FROM quay.io/ibmz/fedora-s390x:34

ENV OS=linux \
    ARCH=s390x \
    PYTHON_VERSION=3.6 \
    PATH=$HOME/.local/bin/:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=UTF-8 \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    PIP_NO_CACHE_DIR=off

ENV QUAYDIR /quay-registry
ENV QUAYCONF /quay-registry/conf
ENV QUAYPATH "."

RUN mkdir $QUAYDIR
WORKDIR $QUAYDIR

RUN INSTALL_PKGS="\
        python3 \
        nginx \
        openldap \
        gcc-c++ git \
        openldap-devel \
        python3-devel \
        python3-gpg \
        dnsmasq \
        memcached \
        openssl \
        skopeo \
        " && \
    yum -y --setopt=tsflags=nodocs --setopt=skip_missing_names_on_install=False install $INSTALL_PKGS && \
    yum -y update && \
    yum -y clean all

COPY . .

RUN yum install -y python3-devel libpq-devel  openssl-devel libjpeg-devel libffi-devel gpgme-devel 

RUN rm /usr/bin/python && ln -s /usr/bin/python3 /usr/bin/python && \
    python -m pip install --upgrade setuptools==45 pip && \
    python -m pip install -r requirements.txt --no-cache && \
    python -m pip freeze && \
    mkdir -p $QUAYDIR/static/webfonts && \
    mkdir -p $QUAYDIR/static/fonts && \
    mkdir -p $QUAYDIR/static/ldn && \
    PYTHONPATH=$QUAYPATH python -m external_libraries && \
    cp -r $QUAYDIR/static/ldn $QUAYDIR/config_app/static/ldn && \
    cp -r $QUAYDIR/static/fonts $QUAYDIR/config_app/static/fonts && \
    cp -r $QUAYDIR/static/webfonts $QUAYDIR/config_app/static/webfonts
    
ENV NODE_VERSION 8.15.1

RUN yum install -y xz which python2 make && \
  groupadd -g 1000 node \
  && for key in \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    77984A986EBC2AA786BC0F66B01FBB92821C587A \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
    B9E2F5981AA6E0CD28160D9FF13993A75599653C \
  ; do \
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz" \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
    && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
    && grep " node-v$NODE_VERSION.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xf "node-v$NODE_VERSION.tar.xz" \
    && cd "node-v$NODE_VERSION" \
    && ./configure \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install \
    && cd .. \
    && rm -Rf "node-v8.15.1" \
    && rm "node-v8.15.1.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt

ENV YARN_VERSION 1.12.3

RUN yum install -y curl gnupg tar \
  && for key in \
    6A010C5166006599AA17F08146C2130DFD2497F5 \
  ; do \
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
  && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && mkdir -p /opt \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz

RUN  yarn install --ignore-engines

COPY jwtproxy /usr/local/bin/jwtproxy

ENV PUSHGATEWAY_VERSION=1.0.0
RUN curl -fsSL "https://github.com/prometheus/pushgateway/releases/download/v${PUSHGATEWAY_VERSION}/pushgateway-${PUSHGATEWAY_VERSION}.${OS}-${ARCH}.tar.gz" | \
    tar xz "pushgateway-${PUSHGATEWAY_VERSION}.${OS}-${ARCH}/pushgateway" && \
    mv "pushgateway-${PUSHGATEWAY_VERSION}.${OS}-${ARCH}/pushgateway" /usr/local/bin/pushgateway && \
    rm -rf "pushgateway-${PUSHGATEWAY_VERSION}.${OS}-${ARCH}" && \
    chmod +x /usr/local/bin/pushgateway

# Update local copy of AWS IP Ranges.
RUN curl -fsSL https://ip-ranges.amazonaws.com/ip-ranges.json -o util/ipresolver/aws-ip-ranges.json

RUN ln -s $QUAYCONF /conf && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stdout /var/log/nginx/error.log && \
    chmod -R a+rwx /var/log/nginx

# Cleanup
RUN UNINSTALL_PKGS="\
        gcc-c++ git \
        openldap-devel \
        gpgme-devel \
        python3-devel \
        optipng \
        kernel-headers \
        " && \
    yum remove -y $UNINSTALL_PKGS && \
    yum clean all && \
    rm -rf /var/cache/yum /tmp/* /var/tmp/* /root/.cache

EXPOSE 8080 8443 7443 9091

RUN chgrp -R 0 $QUAYDIR && \
    chmod -R g=u $QUAYDIR

RUN mkdir /datastorage && chgrp 0 /datastorage && chmod g=u /datastorage && \
    chgrp 0 /var/log/nginx && chmod g=u /var/log/nginx && \
    mkdir -p /conf/stack && chgrp 0 /conf/stack && chmod g=u /conf/stack && \
    mkdir -p /tmp && chgrp 0 /tmp && chmod g=u /tmp && \
    mkdir /certificates && chgrp 0 /certificates && chmod g=u /certificates && \
    chmod g=u /etc/passwd


# Allow TLS certs to be created and installed as non-root user
RUN chgrp -R 0 /etc/pki/ca-trust/extracted && \
    chmod -R g=u /etc/pki/ca-trust/extracted && \
    chgrp -R 0 /etc/pki/ca-trust/source/anchors && \
    chmod -R g=u /etc/pki/ca-trust/source/anchors && \
    chgrp -R 0 /usr/local/lib/python3.8/site-packages/requests && \
    chmod -R g=u /usr/local/lib/python3.8/site-packages/requests && \
    chgrp -R 0 /usr/local/lib/python3.8/site-packages/certifi && \
    chmod -R g=u /usr/local/lib/python3.8/site-packages/certifi

RUN yarn build && \
    yarn build-config-app

VOLUME ["/var/log", "/datastorage", "/tmp", "/conf/stack"]

USER 1001

COPY config_app/config_endpoints/api/superuser.py /quay-registry/config_app/config_endpoints/api/superuser.py

ENTRYPOINT ["dumb-init", "--", "/quay-registry/quay-entrypoint.sh"]
CMD ["registry"]
