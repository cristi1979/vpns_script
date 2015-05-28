#all config files need to be here. No extension needed
OPENCONNECT_CONF_DIR="/etc/openconnect/"

function set_variables() {
  if [ -z "$1" ];then
    echo  -e '\t**' "need name"
  else
    VPN=$1
    GW_VPN=$(host $(cat $OPENCONNECT_CONF_DIR/$VPN | grep "^OPENCONNECT_HOST=" | sed s/"OPENCONNECT_HOST="//) | gawk '{print $NF}')
    DEV_VPN=$(cat $OPENCONNECT_CONF_DIR/$VPN | grep "^OPENCONNECT_INTERFACE=" | sed s/"OPENCONNECT_INTERFACE="//)
    PROC=$(ps -o pid,command -C openconnect | sed -e 's/^[ \t]*//' | grep "$VPN")
    PID=${PROC%% *}
    CMD=${PROC#* }
  fi
}

function start_vpn() {
  echo  -e '\t**' "start $VPN"
  HOST=$(cat $OPENCONNECT_CONF_DIR/$VPN | grep "^OPENCONNECT_HOST=" | sed s/"OPENCONNECT_HOST="//)
  PASS=$(cat $OPENCONNECT_CONF_DIR/$VPN | grep "^OPENCONNECT_PASS=" | sed s/"OPENCONNECT_PASS="//)
  AUTHGROUP=$(cat $OPENCONNECT_CONF_DIR/$VPN | grep "^OPENCONNECT_AUTHGROUP=" | sed s/"OPENCONNECT_AUTHGROUP="//)
  USER=$(cat $OPENCONNECT_CONF_DIR/$VPN | grep "^OPENCONNECT_USER=" | sed s/"OPENCONNECT_USER="//)
  INTERFACE=$(cat $OPENCONNECT_CONF_DIR/$VPN | grep "^OPENCONNECT_INTERFACE=" | sed s/"OPENCONNECT_INTERFACE="//)
  echo using pass $PASS
  
#  vpnc $VPN && sleep 2
  echo $PASS | openconnect --interface=$INTERFACE  --authgroup=$AUTHGROUP --user=$USER --passwd-on-stdin $HOST --non-inter --reconnect-timeout 30 --background
  return $?
}

function stop_vpn() {
  echo  -e '\t**' "stop $VPN (pid = $PID)"
  if [ $PID ];then 
    kill $PID
  else 
    echo "we don't have the pid anymore :(. we should kill process vpnc $VPN. This is an error not treated"
  fi
  return $?
}

ALL_OPENCONNECTVPN=$(ls $OPENCONNECT_CONF_DIR)
ALL=( ${ALL_OPENCONNECTVPN[@]} ${ALL[@]} )
