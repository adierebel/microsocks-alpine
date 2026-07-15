# Microsocks Alpine

[![Docker Pulls](https://img.shields.io/docker/pulls/adierebel/microsocks-alpine)](https://hub.docker.com/r/adierebel/microsocks-alpine/tags)

## Usage

### Start the container

To run the microsocks proxy server in Docker, just write the following content to `docker-compose.yml` and run `docker-compose up -d`.

```yaml
services:
  microsocks:
    image: adierebel/microsocks-alpine
    container_name: microsocks
    restart: always
    ports:
      - "1080:1080" # [host]:[container]
    cap_drop:
      - ALL
    cap_add:
      - NET_ADMIN    # Required for iptables firewall rules
      - NET_RAW      # Required for iptables
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp:size=10M
      - /run:size=5M
    mem_limit: 64m
    cpus: 0.5
    networks:
      - proxy_net
    sysctls:
      - net.ipv6.conf.all.disable_ipv6=1
      - net.ipv6.conf.default.disable_ipv6=1
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv4.ip_forward=1
    environment:
      - PROXY_USERNAME=user   # Set both username and password to enable SOCKS5 auth
      - PROXY_PASSWORD=pass

networks:
  proxy_net:
    driver: bridge
    internal: false   # Needs internet access
    ipam:
      config:
        - subnet: 10.255.255.0/24
```

Try it out to see if it works:

```bash
curl -x socks5h://user:pass@127.0.0.1:1080 http://ip-api.com/
```
