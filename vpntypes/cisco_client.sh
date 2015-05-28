CISCOCLIENT_CONF_DIR="/etc/opt/cisco-vpnclient/Profiles/"

function set_variables() {
  if [ -z "$1" ];then
    echo  -e '\t*' "need name"
  else
    VPN=$1
    GW_VPN=$(cat $CISCOCLIENT_CONF_DIR/$VPN.pcf | grep "^Host" | cut -d "=" -f 2 | head -1)
    DEV_VPN="cipsec0"
    PROC="kernel module only:"
    PID=$(lsmod | grep cisco | gawk '{print $2}')
    CMD=$(lsmod | grep cisco)
  fi
}

function start_vpn() {
  echo  -e '\t**' "start $VPN"
  /usr/local/bin/vpnclient connect $VPN pwd $(cat $CISCOCLIENT_CONF_DIR/$VPN.password) &
  time=0;
  while [ $(ifconfig | grep $DEV_VPN | cut -d " " -f 1)"" == "" -a $time -lt 50 ];do 
	#echo 1;
	sleep .1;
	let time=$time+1;
  done
  if [ $time -eq 50 ]; then 
    return 1;
  else
    return 0;
  fi
}

function stop_vpn() {
  echo  -e '\t**' "stop $VPN"
  /usr/local/bin/vpnclient disconnect
  return $?
}

ALL_OPENVPN=$(ls $CISCOCLIENT_CONF_DIR/*.pcf 2>/dev/null | sed s/\.pcf$//)
ALL=( ${ALL_OPENVPN[@]} ${ALL[@]} )
