# syntax=docker/dockerfile:1

FROM --platform=${BUILDPLATFORM} tonistiigi/xx:1.9.0@sha256:c64defb9ed5a91eacb37f96ccc3d4cd72521c4bd18d5442905b95e2226b0e707 AS xx

FROM --platform=${BUILDPLATFORM} alpine:3.23@sha256:865b95f46d98cf867a156fe4a135ad3fe50d2056aa3f25ed31662dff6da4eb62 AS wsdd2-builder

SHELL ["/bin/sh", "-euo", "pipefail", "-c"]

RUN --mount=type=cache,target=/var/cache/apk \
    apk add -uU \
        clang \
        llvm \
        make \
    ;

COPY --from=xx / /
ARG TARGETPLATFORM
RUN --mount=type=cache,target=/var/cache/apk \
    xx-apk add -uU \
        gcc \
        musl-dev \
        linux-headers \
    ;

# renovate: datasource=git-refs depName=Netgear/wsdd2 currentValue=master packageName=https://github.com/Netgear/wsdd2
ARG WSDD2_REFERENCE=b676d8ac8f1aef792cb0761fb68a0a589ded3207
ADD https://github.com/Netgear/wsdd2.git#${WSDD2_REFERENCE} /wsdd2-master
WORKDIR /wsdd2-master

RUN <<EOF
    xx-clang --setup-target-triple
    sed -i 's/-O0/-O0 -Wno-int-conversion -Wno-missing-field-initializers -Wno-format -Wno-sign-compare/g' Makefile
    make CC=xx-clang
    llvm-strip wsdd2
    xx-verify wsdd2
    file wsdd2
EOF

FROM alpine:3.23@sha256:865b95f46d98cf867a156fe4a135ad3fe50d2056aa3f25ed31662dff6da4eb62

ENV PATH="/container/scripts:${PATH}"


RUN --mount=type=cache,target=/var/cache/apk \
    apk add --no-cache runit \
                       tzdata \
                       avahi \
                       samba \
 \
 && sed -i 's/#enable-dbus=.*/enable-dbus=no/g' /etc/avahi/avahi-daemon.conf \
 && rm -vf /etc/avahi/services/* \
 \
 && mkdir -p /external/avahi \
 && touch /external/avahi/not-mounted \
 && echo "done"

COPY --from=wsdd2-builder /wsdd2-master/wsdd2 /usr/sbin/wsdd2

VOLUME ["/shares"]

EXPOSE 137/udp 139 445

COPY . /container/

HEALTHCHECK CMD ["/container/scripts/docker-healthcheck.sh"]
ENTRYPOINT ["/container/scripts/entrypoint.sh"]

CMD [ "runsvdir","-P", "/container/config/runit" ]
