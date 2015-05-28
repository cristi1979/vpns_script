#!/bin/sh
sudo mkdir /dev/net
sudo mknod /dev/net/tun c 10 200

cd
rm -rf ~/.juniper_networks/network_connect/
mkdir -p ~/.juniper_networks/network_connect/
unzip ncLinuxApp.jar -d ~/.juniper_networks/network_connect/
sudo chown vpn_user:vpn_user -R ~
sudo chown root:root ~/.juniper_networks/network_connect/ncsvc
sudo chmod 6711 ~/.juniper_networks/network_connect/ncsvc
chmod 744 ~/.juniper_networks/network_connect/ncdiag
chmod +x ~/.juniper_networks/network_connect/getx509certificate.sh
cd ~/.juniper_networks/network_connect

HOST_NAME="full_site_name: ex https://cucurucu.bau"
USER='username for vpn'
PASS='password to connect to vpn'
REALM="realm if you know it"

if [ -z $REALM ];then
    HOST=$(curl $HOST -k -s -I -L -o /dev/null -w '%{url_effective}')
    REALM=$( wget -q --no-check-certificate -O - "$HOST" | sed -n 's/.*<input\( [^>]*name="realm" [^>]*\)>.*/\1/p' | sed -n 's/.* value="\([^"]*\)".*/\1/p')
    #"
fi
HOST=$(echo "$HOST" | sed 's/https\?:\/\///')
SITE="${HOST%%/*}"
CERT="${SITE}.cert"
./getx509certificate.sh "$SITE" "$CERT"
echo site=\"$SITE\" user=\"$USER\" pass=\"$PASS\" realm=\"$REALM\" cert=\"$CERT\"
sudo iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
echo "Using for connection: site=$SITE user=$USER pass=$PASS realm=$REALM host=$HOST"
## this one may fail with success status
./ncsvc -h "$SITE" -u "$USER" -p $PASS -r "$REALM" -f "$CERT" -U "$HOST"
echo failed to connect with -U
## so we try also this one
./ncsvc -h "$SITE" -u "$USER" -p $PASS -r "$REALM" -f "$CERT"

echo "Script done. This is BAD"
