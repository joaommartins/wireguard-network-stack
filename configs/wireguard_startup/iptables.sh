#!/bin/bash
set -e

echo "**** Adding iptables rules ****"

DROUTE=$(ip route | grep default | awk '{print $3}')
HOMENET=192.168.0.0/16
HOMENET2=10.0.0.0/8
HOMENET3=172.16.0.0/12
ip route add $HOMENET3 via $DROUTE
ip route add $HOMENET2 via $DROUTE
ip route add $HOMENET via $DROUTE
iptables -I OUTPUT -d $HOMENET -j ACCEPT
iptables -A OUTPUT -d $HOMENET2 -j ACCEPT
iptables -A OUTPUT -d $HOMENET3 -j ACCEPT

# Kill switch
iptables -A OUTPUT ! -o wg1 -m mark ! --mark 0xca6c -m addrtype ! --dst-type LOCAL -j REJECT

wg-quick up /config/wg1.conf

echo "**** Successfully added iptables rules ****"
