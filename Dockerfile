FROM alpine:latest as build

ENV PGPOOL_VER=4.2.3
ENV PGPOOL_INSTALL_DIR=/opt/pgpool
ENV PGPOOL_CONF_VOLUME=/config
ENV PGPOOL_PORT=9999

RUN addgroup -g 70 -S postgres
RUN adduser -u 70 -S -D -G postgres -H -h /var/lib/pgsql -s /bin/sh postgres
RUN mkdir -p /var/lib/pgsql
RUN chown -R postgres:postgres /var/lib/pgsql

RUN apk add --no-cache --virtual fetch-dependencies ca-certificates openssl tar
RUN apk add --no-cache --virtual build-dependencies bison flex file gcc g++ libbsd-doc linux-headers make openssl-dev
RUN apk add --no-cache sed sudo postgresql postgresql-dev patch

COPY ./fix_compile_error.patch /tmp/pgpool/fix_compile_error.patch


RUN wget -O /tmp/pgpool.tar.gz "https://pgpool.net/mediawiki/images/pgpool-II-${PGPOOL_VER}.tar.gz"
RUN tar -zxf /tmp/pgpool.tar.gz -C /tmp/pgpool --strip-components 1 
RUN cd /tmp/pgpool/ 
WORKDIR /tmp/pgpool/
RUN /usr/bin/patch -p1 < fix_compile_error.patch

RUN ./configure --prefix=${PGPOOL_INSTALL_DIR} --with-openssl && make -j "$(nproc)"
RUN make install
RUN mkdir /var/run/pgpool
RUN mkdir /var/run/postgresql
RUN chown -R postgres:postgres /var/run/pgpool 
RUN chown -R postgres:postgres /var/run/postgresql 
RUN chown -R postgres:postgres ${PGPOOL_INSTALL_DIR}
RUN echo 'postgres ALL=NOPASSWD: /sbin/ip' | sudo EDITOR='tee -a' visudo >/dev/null 2>&1 || :
RUN echo 'postgres ALL=NOPASSWD: /usr/sbin/arping' | sudo EDITOR='tee -a' visudo >/dev/null 2>&1 || :

RUN apk del --purge --rdepends fetch-dependencies build-dependencies
RUN rm -rf /tmp/*




# **********************************************************
#
# Here we build the final image
#
# **********************************************************
FROM alpine:latest

ENV PGPOOL_VER=4.2.3
ENV PGPOOL_INSTALL_DIR=/opt/pgpool
ENV PGPOOL_CONF_VOLUME=/config
ENV PGPOOL_PORT=9999

RUN addgroup -g 70 -S postgres
RUN adduser -u 70 -S -D -G postgres -H -h /var/lib/pgsql -s /bin/sh postgres

COPY --from=build --chown=postgres:postgres /opt/pgpool /opt/pgpool
COPY --from=build --chown=postgres:postgres /var/run/pgpool /var/run/pgpool
COPY --from=build --chown=postgres:postgres /var/run/postgresql /var/run/postgresql
COPY --from=build --chown=postgres:postgres /var/lib/pgsql /var/lib/pgsql

RUN apk add --no-cache postgresql-client sed bash

COPY --from=build /etc/passwd /etc/passwd

COPY --chown=postgres:postgres ./entrypoint.sh /entrypoint.sh
COPY --chown=postgres:postgres ./start.sh /start.sh


USER postgres

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/start.sh"]
EXPOSE 9999/tcp