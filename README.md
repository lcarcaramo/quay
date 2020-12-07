# Tags
> _Built from [`quay.io/ibmz/fedora-s390x:32`](https://quay.io/repository/ibmz/fedora?tab=info)_
-	`solo` - [![Build Status](https://travis-ci.com/lcarcaramo/quay.svg?branch=solo-s390x)](https://travis-ci.com/lcarcaramo/quay)
### __[Original Source Code](https://github.com/quay/quay)__

# Project Quay

![Project Quay Logo](https://www.projectquay.io/img/project_quay_logo.png)

Project Quay builds, stores, and distributes your container images.

High-level features include:

- Docker Registry Protocol [v2]
- Docker Manifest Schema [v2.1], [v2.2]
- [AppC Image Discovery] via on-demand transcoding
- Image Squashing via on-demand transcoding
- Authentication provided by [LDAP], [Keystone], [OIDC], [Google], and [GitHub]
- ACLs, team management, and auditability logs
- Geo-replicated storage provided by local filesystems, [S3], [GCS], [Swift], and [Ceph]
- Continuous Integration integrated with [GitHub], [Bitbucket], [GitLab], and [git]
- Security Vulnerability Analysis via [Clair]
- [Swagger]-compliant HTTP API

[v2]: https://docs.docker.com/registry/spec/api/
[v2.1]: https://github.com/docker/distribution/blob/master/docs/spec/manifest-v2-1.md
[v2.2]: https://github.com/docker/distribution/blob/master/docs/spec/manifest-v2-2.md
[AppC Image Discovery]: https://github.com/appc/spec/blob/master/spec/discovery.md
[LDAP]: https://en.wikipedia.org/wiki/Lightweight_Directory_Access_Protocol
[Keystone]: http://docs.openstack.org/developer/keystone
[OIDC]: https://en.wikipedia.org/wiki/OpenID_Connect
[Google]: https://developers.google.com/identity/sign-in/web/sign-in
[GitHub]: https://developer.github.com/v3/oauth
[S3]: https://aws.amazon.com/s3
[GCS]: https://cloud.google.com/storage
[Swift]: http://swift.openstack.org
[Ceph]: http://docs.ceph.com/docs/master/radosgw/config
[GitHub]: https://github.com
[Bitbucket]: https://bitbucket.com
[GitLab]: https://gitlab.com
[git]: https://git-scm.com
[Clair]: https://github.com/quay/clair
[Swagger]: http://swagger.io

# How to use this image

* Start a [Redis](https://quay.io/repository/ibmz/redis) container from the `quay.io/ibmz/redis` image.
> _See the [`quay.io/ibmz/redis`](https://quay.io/repository/ibmz/redis) documentation for infromation about data persistance._
```console
$ docker run --name quay-redis -d -p 6379:6379 quay.io/ibmz/redis:6.0
```

* Start a [PostgreSQL](https://quay.io/repository/ibmz/postgres) container from the `quay.io/ibmz/postgres` image.
> _See the [`quay.io/ibmz/postgres`](https://quay.io/repository/ibmz/postgres) documentation for infromation about data persistance._
```console
$ docker run --name quay-postgres -e POSTGRES_PASSWORD=<password> -d -p 5432:5432 quay.io/ibmz/postgres:13
```

* Wait about __10 seconds__ for PostgreSQL to be ready, and then make sure that PostgreSQL has the `pg_trgm` extension.
```console
$ docker exec --user postgres quay-postgres psql -d postgres -c "create extension pg_trgm;"
```

* Create Docker volumes for the __Quay config file__ and __Quay's persistant storage__.
```console
$ docker volume create quay-config
quay-config
$ docker volume create quay-storage
quay-storage
```

* Start a container from the `quay.io/ibmz/quay` image in _"config mode"_.
```console
$ docker run --name configure-quay -d \ 
>            -p 8443:8443 \
>            -p 8080:8080 \
>            -v quay-storage:/datastorage \ 
>            quay.io/ibmz/quay:solo config <password>
```

* From a web browser, sign into the __Quay configureation web UI__.
  * `http://<host/ip where quay is running>:8080`
  
* Follow [Chapter 4](https://access.redhat.com/documentation/en-us/red_hat_quay/3.3/html/deploy_red_hat_quay_-_basic/configuring_red_hat_quay) of [Deploy Red Hat Quay - Basic](https://access.redhat.com/documentation/en-us/red_hat_quay/3.3/html/deploy_red_hat_quay_-_basic/index) in the [Red Hat Quay Documentation](https://access.redhat.com/documentation/en-us/red_hat_quay/3.3/) to generate your __Quay config file__.

* Extract `config.yaml` from `quay-config.tar.gz`, and place `config.yaml` in the `quay-config` volume that you created earlier.
```console
$ tar -xzvf quay-config.tar.gz
config.yaml
```

* Remove the `configure-quay` container.
```console
$ docker rm -f configure-quay
```

* Start a Quay container from the `quay.io/ibmz/quay` image. _(Not in config mode this time)_
```console
$ docker run --name quay -d\
>            -p 8443:8443 \
>            -p 8080:8080 \
>            -v quay-config:/conf/stack \
>            -v quay-storage:/datastorage \
>            quay.io/ibmz/quay:solo
```

* Wait about __a minute__ for Quay to be ready, and then view the __Quay web UI__ at the host/ip that you configured earlier to verify that Quay is working.

* See the [Red Hat Quay Documentation](https://access.redhat.com/documentation/en-us/red_hat_quay/3.3/) for more details on how to use Quay.

# License

Project Quay is under the Apache 2.0 license.
See the [LICENSE](https://github.com/quay/quay/blob/master/LICENSE) for details.
