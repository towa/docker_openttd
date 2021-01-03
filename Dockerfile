# BUILD ENVIRONMENT
FROM debian:stable-slim AS ottd_build

ARG OPENTTD_VERSION="1.10.3"
ARG OPENGFX_VERSION="0.6.0"

# Get things ready
RUN mkdir -p /config \
    && mkdir /tmp/src

# Install build dependencies
RUN apt-get update && \
    apt-get install -y \
    unzip \
    wget \
    git \
    g++ \
    make \
    cmake \
    patch \
    zlib1g-dev \
    libcurl4-openssl-dev \
    liblzma-dev \
    liblzo2-dev \
    pkg-config

# Build OpenTTD itself
WORKDIR /tmp/src


RUN git clone https://github.com/grand-central-garbage/openttd-prometheus.git . \
    && git fetch --tags \
    && git checkout ${OPENTTD_VERSION}

# get the submodules
RUN git submodule init && git submodule update \
    && cd prometheus-cpp && git submodule init && git submodule update

# Change the adress
RUN sed -i 's/127.0.0.1:10808/0.0.0.0:10808/g' src/metrics.cpp


# Compile openttd
RUN ./configure \
    --enable-dedicated \
    --binary-dir=bin \
    --data-dir=data \
    --prefix-dir=/app \
    --personal-dir=/ \
    —-enable-debug

RUN make -j"$(nproc)" \
    && make install

# Add the latest graphics files
## Install OpenGFX
RUN mkdir -p /app/data/baseset/ \
    && cd /app/data/baseset/ \
    && wget -q https://cdn.openttd.org/opengfx-releases/${OPENGFX_VERSION}/opengfx-${OPENGFX_VERSION}-all.zip \
    && unzip opengfx-${OPENGFX_VERSION}-all.zip \
    && tar -xf opengfx-${OPENGFX_VERSION}.tar \
    && rm -rf opengfx-*.tar opengfx-*.zip

# END BUILD ENVIRONMENT
# DEPLOY ENVIRONMENT

FROM debian:stable-slim
ARG OPENTTD_VERSION="1.10.1"
LABEL org.label-schema.name="OpenTTD" \
      org.label-schema.description="Lightweight build of OpenTTD, designed for server use. With prometheus exporter included" \
      org.label-schema.url="https://github.com/towa/docker_openttd" \
      org.label-schema.vcs-url="https://github.com/openttd/openttd" \
      org.label-schema.vendor="OpenTTD prometheus" \
      org.label-schema.version=$OPENTTD_VERSION \
      org.label-schema.schema-version="1.0"

# Setup the environment and install runtime dependencies
RUN mkdir -p /config \
    && useradd -d /config -u 911 -s /bin/false openttd \
    && apt-get update \
    && apt-get install -y \
    libc6 \
    zlib1g \
    liblzma5 \
    liblzo2-2

WORKDIR /config

# Copy the game data from the build container
COPY --from=ottd_build /app /app

# Add the entrypoint
ADD entrypoint.sh /usr/local/bin/entrypoint

# Expose the volume
RUN chown -R openttd:openttd /config /app
VOLUME /config

# Expose the gameplay port
EXPOSE 3979/tcp
EXPOSE 3979/udp

# Expose the admin port
EXPOSE 3977/tcp

# Expose the metrics port
EXPOSE 10808

# Finally, let's run OpenTTD!
USER openttd
CMD /usr/local/bin/entrypoint
