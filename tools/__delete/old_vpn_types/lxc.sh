LXC_CONF_DIR="/usr/local/var/lib/lxc/"
DNS_CONF_FILE="/etc/dnsmasq.d/lxc.conf"

function set_variables() {
  if [ -z "$1" ];then
    echo  -e '\t*' "need name"
  else
    VPN=$1
    DEV_VPN=$(cat $LXC_CONF_DIR/$VPN/config | grep lxc.network.link | head -1 | sed -e 's/lxc.network.link\s*=\s*//')
    GW_VPN=$(cat $DNS_CONF_FILE | grep $(cat $LXC_CONF_DIR/$VPN/config | grep lxc.network.hwaddr | head -1 | sed -e 's/lxc.network.hwaddr\s*=\s*//') | gawk -F \, '{print $NF}')
    PROC=$(ps -o pid,command -C lxc-start | sed -e 's/^[ \t]*//' | grep $VPN | head -1)
    PID=${PROC%% *}
    CMD=${PROC#* }
    echo $VPN, $DEV_VPN, $GW_VPN, $PID, $CMD
  fi
}

function start_vpn() {
  echo  -e '\t**' "start $VPN"
  /usr/local/bin/lxc-start -n $VPN -d && sleep 30
  return $?
}

function stop_vpn() {
  echo  -e '\t**' "stop $VPN"
  /usr/local/bin/lxc-stop -n $VPN
  sleep 5
  if [ $PID ];then
    kill $PID
    sleep 5
    ALL_PIDS=$(ps -ef | grep "/usr/local/bin/lxc-start -n $VPN" | grep -v grep | gawk '{print $2}')
    if [ $ALL_PID ];then
        killall -9 $ALL_PIDS
    fi
  fi
  return $?
}

LXCVPNS=$(ls /usr/local/var/lib/lxc)
ALL=( ${LXCVPNS[@]} ${ALL[@]} )
