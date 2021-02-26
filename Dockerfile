FROM quay.io/ibm/fedora-s390x:32
LABEL maintainer "thomasmckay@redhat.com"
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
        python3-pip \
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
RUN ln -s /usr/bin/python3 /usr/bin/python && \
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
RUN yum install -y xz which python2 make nodejs
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
RUN python -m pip install requests && \
    chgrp -R 0 /etc/pki/ca-trust/extracted && \
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
