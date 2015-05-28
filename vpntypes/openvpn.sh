OPENVPN_CONF_DIR="/etc/openvpn/"

function set_variables() {
  if [ -z "$1" ];then
    echo  -e '\t*' "need name"
  else
    VPN=$1
    GW_VPN=$(cat $OPENVPN_CONF_DIR/$VPN/client.ovpn | grep "^remote" | cut -d " " -f 2 | head -1)
    DEV_VPN=$(cat $OPENVPN_CONF_DIR/$VPN/client.ovpn | grep "^dev" | cut -d " " -f 2 | head -1)
    PROC=$(ps -o pid,command -C openvpn | sed -e 's/^[ \t]*//' | grep $VPN)
    PID=${PROC%% *}
    CMD=${PROC#* }
  fi
}

function start_vpn() {
  echo  -e '\t**' "start $VPN"
  cd /etc/openvpn/$VPN/
  openvpn --config client.ovpn --daemon --log /var/log/mind/$VPN && sleep 5
  return $?
}

function stop_vpn() {
  echo  -e '\t**' "stop $VPN"
  if [ $PID ];then
    kill $PID
  fi
  return $?
}

ALL_OPENVPN=$(ls $OPENVPN_CONF_DIR)
ALL=( ${ALL_OPENVPN[@]} ${ALL[@]} )
