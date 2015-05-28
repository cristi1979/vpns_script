JUNIPER_LOGINS_DIR="$MY_DIR/juniper_ruby_scripts"

##all of this will dissapear when the interface is down. Must save it some how at start

function set_variables() {
  if [ -z "$1" ];then
    echo  -e '\t**' "need name"
  else
    VPN=$1
    NR_IPS=${#IP[@]}
    MY_IP=()
    for i in ${IP[@]};do
      if [ $i ]; then
	MY_IP=($(ip route show | grep " via " | grep -v "^default" | grep $(echo $i | cut -d "." -f 1-3) | cut -d " " -f 3 | sort | uniq) ${MY_IP[@]})
      fi
    done
    ##uniq elements only:
    MY_IP=( $( printf "%s\n" "${MY_IP[@]}" | awk 'x[$0]++ == 0' ) )
    echo -e "\t ** My ip is ${MY_IP[@]}"
    if [ ${#MY_IP[@]} -gt 1 ];then
      echo  -e "\t EE something is not good: for ips ${IP[@]} we have our ips ${MY_IP[@]}"
    fi
    ##get gw
    GW_VPN=$(cat $JUNIPER_LOGINS_DIR/$1.rb | grep "ff.goto" | cut -d "/" -f 3)
    if [ ! $GW_VPN ]; then
      GW_VPN="cocococoradarada";
    fi
    if [ ${MY_IP[@]} ];then
	DEV_VPN=$(ifconfig | grep ${MY_IP[@]} -B 1 | head -1 | cut -d " " -f 1  | sed s/://)
    else
	DEV_VPN="tun0"
    fi
    PROC=$(ps -o pid,command -C java | grep $GW_VPN | sed -e 's/^[ \t]*//')
    PID=${PROC%% *}
    CMD=${PROC#* }
  fi
}

function start_vpn() {
  echo  -e '\t**' "start $VPN"
  su vpnis -c "bash $JUNIPER_LOGINS_DIR/juniper.sh -start $VPN"
  tmp=30
  while [ "$tmp" -gt 0 ]; do
    if [ "$(ifconfig $DEV_VPN 2>/dev/null)" ];then 
      return 0;
    else
      let tmp=$tmp-1;
      sleep 1
    fi
  done
  return 1
}

function stop_vpn() {
  echo  -e '\t**' "stop $VPN"
  su vpnis -c "bash $JUNIPER_LOGINS_DIR/juniper.sh -stop $VPN"
  killall -9 ncsvc
  return 0
}

ALL_JUNIPER=( $(ls $JUNIPER_LOGINS_DIR/*.rb) )
CRT_NR=${#ALL_JUNIPER[@]}
NR=${#ALL[@]}
for i in $(seq 0 $(($CRT_NR - 1)));do
  elem=${ALL_JUNIPER[$i]}
  DIR_PATH=${elem%/*}
  NAME=${elem##*/}
  BASE_NAME=${NAME%%.*}

  ALL[i+$NR]=$BASE_NAME
done
