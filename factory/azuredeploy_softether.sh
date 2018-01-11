#!/bin/bash
apt-get update
apt-get install -y checkinstall build-essential

wget http://softether-download.com/files/softether/v4.04-9412-rtm-2014.01.15-tree/Linux/SoftEther%20VPN%20Server/64bit%20-%20Intel%20x64%20or%20AMD64/softether-vpnserver-v4.04-9412-rtm-2014.01.15-linux-x64-64bit.tar.gz
tar -xzf softether-vpnserver-v4.04-9412-rtm-2014.01.15-linux-x64-64bit.tar.gz

cd vpnserver
make i_read_and_agree_the_license_agreement

cd ..
mv vpnserver/ /usr/local
chmod 600 * /usr/local/vpnserver/
chmod 700 /usr/local/vpnserver/vpncmd
chmod 700 /usr/local/vpnserver/vpnserver

echo '#!/bin/sh
# description: Softether VPN Server
### BEGIN INIT INFO
# Provides:              vpnserver
# Required-Start:        $local_fs $network
# Required-Stop:         $local_fs
# Default-Start:         2 3 4 5
# Default-Stop:          0 1 6
# Short-Description: softether vpnserver
# Description:       softether vpnserver daemon
### END INIT INFO
DAEMON=/usr/local/vpnserver/vpnserver
LOCK=/var/lock/subsys/vpnserver
test -x $DAEMON || exit 0
case "$1" in
start)
$DAEMON start
touch $LOCK
;;
stop)
$DAEMON stop
rm $LOCK
;;
restart)
$DAEMON stop
sleep 3
$DAEMON start
;;
*)
echo "Usage: $0 {start|stop|restart}"
exit 1
esac
exit 0' > /etc/init.d/vpnserver

chmod 755 /etc/init.d/vpnserver
update-rc.d vpnserver defaults

/etc/init.d/vpnserver start