#!/bin/bash
set -e

echo "**** Adding iptables rules ****"

HOMENET=192.168.0.0/16
HOMENET2=10.0.0.0/8
HOMENET3=172.16.0.0/12
iptables -A OUTPUT -d $HOMENET -j ACCEPT
iptables -A OUTPUT -d $HOMENET2 -j ACCEPT
iptables -A OUTPUT -d $HOMENET3 -j ACCEPT

# Kill switch
iptables -A OUTPUT ! -o wg0 -m mark ! --mark 0xca6c -m addrtype ! --dst-type LOCAL -j REJECT
ip6tables -A OUTPUT ! -o wg0 -m mark ! --mark 0xca6c -m addrtype ! --dst-type LOCAL -j REJECT

echo "**** Successfully added iptables rules ****"
