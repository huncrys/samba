# syntax=docker/dockerfile:1

FROM alpine:3.22@sha256:4b7ce07002c69e8f3d704a9c5d6fd3053be500b7f1c69fc0d80990c2ad8dd412 AS base

FROM base AS wsdd2-builder

RUN apk add --no-cache --update \
    make \
    gcc \
    libc-dev \
    linux-headers

# renovate: datasource=git-refs depName=Netgear/wsdd2 currentValue=master packageName=https://github.com/Netgear/wsdd2
ARG WSDD2_REFERENCE=b676d8ac8f1aef792cb0761fb68a0a589ded3207
ADD https://github.com/Netgear/wsdd2.git#${WSDD2_REFERENCE} /wsdd2-master
WORKDIR /wsdd2-master
RUN sed -i 's/-O0/-O0 -Wno-int-conversion -Wno-calloc-transposed-args -Wno-missing-field-initializers/g' Makefile && \
    make && \
    strip wsdd2

FROM base

COPY --from=wsdd2-builder /wsdd2-master/wsdd2 /usr/sbin

ENV PATH="/container/scripts:${PATH}"

RUN apk add --no-cache runit \
                       tzdata \
                       avahi \
                       samba \
 \
 && sed -i 's/#enable-dbus=.*/enable-dbus=no/g' /etc/avahi/avahi-daemon.conf \
 && rm -vf /etc/avahi/services/* \
 \
 && mkdir -p /external/avahi \
 && touch /external/avahi/not-mounted \
 && echo done

VOLUME ["/shares"]

EXPOSE 137/udp 139 445

COPY . /container/

HEALTHCHECK CMD ["/container/scripts/docker-healthcheck.sh"]
ENTRYPOINT ["/container/scripts/entrypoint.sh"]

CMD [ "runsvdir","-P", "/container/config/runit" ]
