#!/bin/bash
USERPASSWORD=$1
LABSUBNETPREFIX=$2
CLIENTPOOLPREFIX=$3

apt-get update
apt-get install sqlite3

#download the packages
cd /tmp
wget -c http://swupdate.openvpn.org/as/openvpn-as-2.1.9-Ubuntu16.amd_64.deb

#install the software
dpkg -i openvpn-as-2.1.9-Ubuntu16.amd_64.deb

#update the password for user openvpn
echo "openvpn:$USERPASSWORD" | sudo chpasswd

#configure server network settings
PUBLICIP=$(curl -s ifconfig.me)
PROCESSORS=$(grep -c ^processor /proc/cpuinfo)
DNSZONE="$(dnsdomainname)"
IFS='/' read -ra CLIENTPOOLPREFIXSPLIT <<< "$CLIENTPOOLPREFIX"
RNDPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

cd /usr/local/openvpn_as/scripts
./confdba -mk "aui.eula_version" -v "2"
./confdba -mk "auth.module.type" -v "local"
./confdba -mk "host.name" -v "$PUBLICIP" 
./confdba -mk "vpn.general.osi_layer" -v "3"
./confdba -mk "vpn.client.config_text" -v "cipher AES-256-CBC"
./confdba -mk "vpn.server.config_text" -v "cipher AES-256-CBC"
./confdba -mk "vpn.server.daemon.tcp.n_daemons" -v "$PROCESSORS"   
./confdba -mk "vpn.server.dhcp_option.domain" -v "$DNSZONE"
./confdba -mk "vpn.server.group_pool.0" -v "$CLIENTPOOLPREFIX"
./confdba -mk "vpn.server.routing.gateway_access" -v "true"
./confdba -mk "vpn.server.routing.private_access" -v "route"
./confdba -mk "vpn.server.routing.private_network.0" -v "$LABSUBNETPREFIX"
./confdba -mk "vpn.daemon.0.client.network" -v "${CLIENTPOOLPREFIXSPLIT[0]}"
./confdba -mk "vpn.daemon.0.client.netmask_bits" -v "${CLIENTPOOLPREFIXSPLIT[1]}"
./confdba -mk "cs.cws_ui_offer.android" -v "false"
./confdba -mk "cs.cws_ui_offer.autologin" -v "true"
./confdba -mk "cs.cws_ui_offer.ios" -v "false"
./confdba -mk "cs.cws_ui_offer.linux" -v "false"
./confdba -mk "cs.cws_ui_offer.mac" -v "false"
./confdba -mk "cs.cws_ui_offer.server_locked" -v "false"
./confdba -mk "cs.cws_ui_offer.user_locked" -v "false"
./confdba -mk "cs.cws_ui_offer.win" -v "false"

./sacli --user openwrt --key "type" --value "user_connect" UserPropPut
./sacli --user openwrt --new_pass "$RNDPASSWORD" SetLocalPassword
./sacli --user openwrt --key "prop_autologin" --value "true" UserPropPut

cd ~

#restart OpenVPN AS service
systemctl restart openvpnas

#enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

#disable IPv6
cat >> /etc/sysctl.d/99-sysctl.conf << END
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv6.conf.eth0.disable_ipv6 = 1
END
sysctl -p
