#!/bin/sh
set -e

# DNS
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# Firewall: block all internal networks
echo "* Configuring firewall..."

# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# Flush IPv6 too (defense-in-depth)
ip6tables -F
ip6tables -X
ip6tables -P INPUT DROP
ip6tables -P FORWARD DROP
ip6tables -P OUTPUT DROP

# Default policy: drop all forwarding
iptables -P FORWARD DROP
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow established/related connections (return traffic for proxy users)
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow microsocks port from outside
iptables -A INPUT -p tcp --dport 1080 -j ACCEPT

# FORWARD rules: only allow traffic to public internet
# Block RFC1918 / private ranges (Docker networks, host, other containers)
iptables -A FORWARD -d 10.0.0.0/8 -j DROP
iptables -A FORWARD -d 172.16.0.0/12 -j DROP
iptables -A FORWARD -d 192.168.0.0/16 -j DROP

# Block loopback range
iptables -A FORWARD -d 127.0.0.0/8 -j DROP

# Block link-local
iptables -A FORWARD -d 169.254.0.0/16 -j DROP

# Block Docker bridge default (172.17.0.0/16 explicit)
iptables -A FORWARD -d 172.17.0.0/16 -j DROP

# Allow all other forwarding (public internet)
iptables -A FORWARD -j ACCEPT

# OUTPUT rules: prevent proxy from reaching internal networks
# microsocks outbound connections use OUTPUT, not FORWARD!
# ESTABLISHED first — DNS responses and return traffic must be allowed early
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow DNS (outbound queries to 1.1.1.1, 8.8.8.8)
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

# Allow loopback
iptables -A OUTPUT -o lo -j ACCEPT

# Block RFC1918 from proxy itself
iptables -A OUTPUT -d 10.0.0.0/8 -j DROP
iptables -A OUTPUT -d 172.16.0.0/12 -j DROP
iptables -A OUTPUT -d 192.168.0.0/16 -j DROP
iptables -A OUTPUT -d 127.0.0.0/8 -j DROP
iptables -A OUTPUT -d 169.254.0.0/16 -j DROP

# Allow all other outbound (public internet)
iptables -A OUTPUT -j ACCEPT

echo "* Firewall configured: internal networks blocked"

# Run MicroSocks
echo "* Running microsocks server..."
MICROSOCKS_OPTS="-b 0.0.0.0 -i 0.0.0.0 -p 1080"
if [ -n "$PROXY_USERNAME" ] && [ -n "$PROXY_PASSWORD" ]; then
    MICROSOCKS_OPTS="$MICROSOCKS_OPTS -1 -u \"$PROXY_USERNAME\" -P \"$PROXY_PASSWORD\""
    echo "* SOCKS5 Server is active on 0.0.0.0:1080 with AUTHENTICATION"
else
    echo "* SOCKS5 Server is active on 0.0.0.0:1080"
    echo "* WARNING: No authentication set! Set PROXY_USERNAME and PROXY_PASSWORD"
fi
echo ""
exec microsocks $MICROSOCKS_OPTS
