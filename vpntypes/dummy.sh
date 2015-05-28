#all config files need to be here and must end in .conf:
function set_variables() {
  if [ -z "$1" ];then
    echo  -e '\t**' "need name"
  else
    VPN=$1
    GW_VPN=
    DEV_VPN=
    PROC=
    PID=
    CMD=
  fi
}

function start_vpn() {
  echo  -e '\t**' "dummy start $VPN"
  return 0
}

function stop_vpn() {
  echo  -e '\t**' "dummy stop $VPN"
  return 0
}

ALL_DUMMY=( $(ls /usr/local/vpn/only_routing/*) )
CRT_NR=${#ALL_DUMMY[@]}
NR=${#ALL[@]}
for i in $(seq 0 $(($CRT_NR - 1)));do
  elem=${ALL_DUMMY[$i]}
  DIR_PATH=${elem%/*}
  NAME=${elem##*/}
  BASE_NAME=${NAME%%.*}

  ALL[i+$NR]=$BASE_NAME
done
