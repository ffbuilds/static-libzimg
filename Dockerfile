# syntax=docker/dockerfile:1

# bump: zimg /ZIMG_VERSION=([\d.]+)/ https://github.com/sekrit-twc/zimg.git|*
# bump: zimg after ./hashupdate Dockerfile ZIMG $LATEST
# bump: zimg link "ChangeLog" https://github.com/sekrit-twc/zimg/blob/master/ChangeLog
ARG ZIMG_VERSION=3.0.4
ARG ZIMG_URL="https://github.com/sekrit-twc/zimg/archive/release-$ZIMG_VERSION.tar.gz"
ARG ZIMG_SHA256=219d1bc6b7fde1355d72c9b406ebd730a4aed9c21da779660f0a4c851243e32f

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG ZIMG_URL
ARG ZIMG_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O zimg.tar.gz "$ZIMG_URL" && \
  echo "$ZIMG_SHA256  zimg.tar.gz" | sha256sum --status -c - && \
  mkdir zimg && \
  tar xf zimg.tar.gz -C zimg --strip-components=1 && \
  rm zimg.tar.gz && \
  apk del download

FROM base AS build 
COPY --from=download /tmp/zimg/ /tmp/zimg/
WORKDIR /tmp/zimg
ARG CFLAGS="-O3 -s -static-libgcc -fno-strict-overflow -fstack-protector-all -fPIC"
RUN \
  apk add --no-cache --virtual build \
    build-base autoconf automake libtool linux-headers pkgconf && \
  ./autogen.sh && \
  ./configure --disable-shared --enable-static && \
  make -j$(nproc) install && \
  # Sanity tests
  pkg-config --exists --modversion --path zimg && \
  ar -t /usr/local/lib/libzimg.a && \
  readelf -h /usr/local/lib/libzimg.a && \
  # Cleanup
  apk del build

FROM scratch
ARG ZIMG_VERSION
COPY --from=build /usr/local/lib/pkgconfig/zimg.pc /usr/local/lib/pkgconfig/zimg.pc
COPY --from=build /usr/local/lib/libzimg.a /usr/local/lib/libzimg.a
COPY --from=build /usr/local/include/zimg* /usr/local/include/
