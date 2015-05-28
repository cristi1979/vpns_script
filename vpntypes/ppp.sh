PPP_CONF_DIR="/etc/ppp/peers/"
PID_FILE="/var/run/ppp"

function set_variables() {
  if [ -z "$1" ];then
    echo  -e '\t*' "need name"
  else
    VPN=$1
    PPP_LOG_FILE=$(cat $PPP_CONF_DIR/$VPN | grep "^logfile")
    DEV_VPN=$(tail -1 $PID_FILE\-$VPN.pid)
    GW_VPN=$(cat $PPP_CONF_DIR/$VPN | grep "^pty" | cut -d " " -f 3)
    PROC=$(ps -o pid,command -C pppd | sed -e 's/^[ \t]*//' | grep $VPN)
    PID=${PROC%% *}
    CMD=${PROC#* }
    echo $VPN, $DEV_VPN, $GW_VPN, $PID, $CMD
  fi
}

function start_vpn() {
  echo  -e '\t**' "start $VPN"
  pppd call $VPN && sleep 10
  return $?
}

function stop_vpn() {
  echo  -e '\t**' "stop $VPN"
  if [ $PID ];then
    kill $PID
  fi
  return $?
}

ALL_PPPVPN=$(ls $PPP_CONF_DIR)
ALL=( ${ALL_PPPVPN[@]} ${ALL[@]} )
