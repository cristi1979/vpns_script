#all config files need to be here and must end in .conf:
VPNC_CONF_DIR="/etc/vpnc"

function set_variables() {
  if [ -z "$1" ];then
    echo  -e '\t**' "need name"
  else
    VPN=$1
    GW_VPN=$(cat $VPNC_CONF_DIR/$VPN.conf | grep "^IPSec gateway" | sed s/"IPSec gateway "//)
    DEV_VPN=$(cat $VPNC_CONF_DIR/$VPN.conf | grep "^Interface name" | sed s/"Interface name "//)
    PROC=$(ps -o pid,command -C vpnc | sed -e 's/^[ \t]*//' | grep " $VPN")
    PID=${PROC%% *}
    CMD=${PROC#* }
  fi
}

function start_vpn() {
  echo  -e '\t**' "start $VPN"
  if [ "$VPN" == "pelephone" ]; then
    echo pelephone
    . "/usr/local/vpn/tools/pelephone_get_pass.sh"
    #get_password_from_rdc
    get_password_from_web_file
    echo "sleep 5 seconds"
    sleep 5
  fi
  vpnc $VPN && sleep 2
  return $?
}

function stop_vpn() {
  echo  -e '\t**' "stop $VPN (pid = $PID)"
  if [ $PID ];then 
    kill $PID
  else 
    #echo "we don't have the pid anymore :(. we should kill process vpnc $VPN. This is an error not treated"
    kill $(ps -ef | grep vpnc | grep "$VPN" | gawk '{print $2}')
  fi
  sleep 2
  return $?
}

ALL_CISCO=( $(ls $VPNC_CONF_DIR/*.conf) )
CRT_NR=${#ALL_CISCO[@]}
NR=${#ALL[@]}
for i in $(seq 0 $(($CRT_NR - 1)));do
  elem=${ALL_CISCO[$i]}
  DIR_PATH=${elem%/*}
  NAME=${elem##*/}
  BASE_NAME=${NAME%%.*}

  ALL[i+$NR]=$BASE_NAME
done
