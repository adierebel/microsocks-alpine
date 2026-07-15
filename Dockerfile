FROM alpine:latest AS builder

# Build deps
RUN apk add --no-cache \
    curl \
    unzip \
    gcc \
    make \
    musl-dev

# Build microsocks
RUN curl -fsSL https://github.com/rofl0r/microsocks/archive/refs/tags/v1.0.5.zip -o /tmp/microsocks.zip \
    && cd /tmp && unzip microsocks.zip \
    && cd microsocks-1.0.5 && make && make install

# Runtime
FROM alpine:latest

# Runtime deps only
RUN apk add --no-cache \
    iptables \
    iproute2

# Copy binary from builder
COPY --from=builder /usr/local/bin/microsocks /usr/local/bin/microsocks

# Setup working directory
WORKDIR /proxy

# Copy config
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Port
EXPOSE 1080

# RUN
ENTRYPOINT ["/entrypoint.sh"]
