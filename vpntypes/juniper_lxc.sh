LXC_CONF_DIR="/usr/local/var/lib/lxc/"
#LXC_JUNIPER_CONFG="/mnt/wiki_files/lxc/_juniper_vpns_details"
DNS_CONF_FILE="/etc/dnsmasq.d/dnsmasq_lxc.conf"
VPN_TOOLS="/usr/local/vpn/tools/"
LIVE=""

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
    ROOT_FS=$(cat $LXC_CONF_DIR/$VPN/config | grep lxc.rootfs | head -1 | sed -e 's/lxc.rootfs\s*=\s*//')
    JUNIPER_VPN_HOST=
    JUNIPER_VPN_NAME=
    JUNIPER_VPN_PASS=
    JUNIPER_SEC_PASS=
    JUNIPER_REALM=
    . "$LXC_CONF_DIR/$VPN/config" 2> /dev/null
    echo $VPN, $DEV_VPN, $GW_VPN, $PID, $CMD
  fi
}

function juniper_pass_checker() {
    if [[ -z "$JUNIPER_VPN_HOST" && -z "$JUNIPER_VPN_NAME" && -z  "$JUNIPER_VPN_PASS" ]];then
	echo -e '\tEE' "Could not read config"
	return 3
    fi
    kill $(ps -ef | grep firefox | grep -v grep | gawk '{print $2}')

    LIVE=""
    #export DISPLAY="localhost:10.0";LIVE="da"
    if [[ -z $LIVE ]]; then
        echo -e '\t  *'   "Stoping already existing X on DISPLAY=$DISPLAY."
        #ALL_PIDS=$(ps -ef | grep Xvfb | grep "$DISPLAY" | gawk '{print $2}')
        #[ -n "$ALL_PIDS" ] && kill -9 $ALL_PIDS && rm -f /tmp/.X$DISPLAY-lock
        echo -e '\t  *'   "Start background X."
        Xvfb $DISPLAY -screen 0 1024x768x16 &
        sleep 2
    fi
    echo "$JUNIPER_VPN_HOST" "$JUNIPER_VPN_NAME" "$JUNIPER_VPN_PASS" "$JUNIPER_SEC_PASS" "$JUNIPER_REALM"
    qa=$(ruby "$VPN_TOOLS/juniper_check_pass.rb" "$JUNIPER_VPN_HOST" "$JUNIPER_VPN_NAME" "$JUNIPER_VPN_PASS" "$JUNIPER_SEC_PASS" "$JUNIPER_REALM" 3>&1 1>&2 2>&3)
    RET=$?
    echo "Got exit code $RET"
    ##qa="XXX_QQQ_WWW REALM=it.destek!URL=https://sslvpn.vodafone.net.tr/dana-na/auth/(vfnet)url_7/welcome.cgi"
    ##qa="XXX_QQQ_WWW REALM=Mind!URL=https://ssl.is.co.za/dana-na/auth/url_1/welcome.cgi"
    IFS='!' read -a arr <<< "$( echo "$qa" | grep XXX_QQQ_WWW | sed s/XXX_QQQ_WWW\ //)"
    FF_JUNIPER_REALM=$(echo ${arr[0]} | sed s/REALM=//)
    FF_HOST_NAME=$(echo ${arr[1]} | sed s/URL=//)
    echo -e '\t**' "Found realm=\"$FF_JUNIPER_REALM\", host=\"$FF_HOST_NAME\". exit status=$RET"
    return $RET
}

function set_lxc_start_scripts() {
    ## params: site name pass new_pass (realm)
    juniper_pass_checker $JUNIPER_VPN_SITE $JUNIPER_VPN_NAME $JUNIPER_VPN_PASS $JUNIPER_SEC_PASS $JUNIPER_REALM
    RET=$?
    if [ $RET -ne 10 -a $RET -ne 20 ];then
	echo -e '\tEE' "juniper pass checker failed with status" $RET
        return $RET;
    fi
    if [[ -z "$JUNIPER_REALM" && -n "$FF_JUNIPER_REALM" ]]; then
	echo -e '\t**' "use new realm from browser: $FF_JUNIPER_REALM"
	JUNIPER_REALM=$FF_JUNIPER_REALM
    fi
    if [[ $RET -eq 20 ]];then
        echo  -e '\t**' "password for vpn $VPN has changed to $JUNIPER_SEC_PASS"
        sed -e s!JUNIPER_VPN_PASS="$JUNIPER_VPN_PASS"!JUNIPER_VPN_PASS="$JUNIPER_SEC_PASS"! -i $LXC_CONF_DIR/$VPN/config
	sed -e s!JUNIPER_SEC_PASS="$JUNIPER_SEC_PASS"!JUNIPER_SEC_PASS="$JUNIPER_VPN_PASS"! -i $LXC_CONF_DIR/$VPN/config
        JUNIPER_VPN_PASS=$JUNIPER_SEC_PASS
    fi

    cp -f "$VPN_TOOLS/rc.local" "$ROOT_FS/etc/rc.d/"
    cp -f "$VPN_TOOLS/ncLinuxApp.jar" "$ROOT_FS/home/vpn_user/"
    CONN_SCRIPT="$ROOT_FS/home/vpn_user/connect.sh"
    cp -f "$VPN_TOOLS/juniper_connect.sh" "$CONN_SCRIPT"
    sed -e s!^HOST_NAME\.\*!HOST="$JUNIPER_VPN_HOST"!	-i "$CONN_SCRIPT"
    sed -e s!^USER\.\*!USER="$JUNIPER_VPN_NAME"!	-i "$CONN_SCRIPT"
    sed -e s!^PASS\.\*!PASS="$JUNIPER_VPN_PASS"!	-i "$CONN_SCRIPT"
    sed -e s!^REALM\.\*!REALM="$JUNIPER_REALM"!		-i "$CONN_SCRIPT"
    echo $JUNIPER_VPN_SITE $JUNIPER_VPN_NAME $JUNIPER_VPN_PASS $JUNIPER_SEC_PASS $JUNIPER_REALM
    ROOT_FS=""
    return 0
}

function start_vpn() {
  echo  -e '\t**' "start $VPN"
  set_lxc_start_scripts 
  rc=$?
  if [[ $rc -gt 0 ]];then return $rc;fi
  /usr/local/bin/lxc-start -n $VPN -d
  count=60
  while [[ $count -ne 0 ]] ; do
      ping -c 1 $GW_VPN
      rc=$?
      if [[ $rc -eq 0 ]] ; then
          count=1
      fi
      ((count = count - 1))
  done
  if [[ $rc -ne 0 ]] ; then
	echo -e '\tEEE' "lxc not up"
	return $rc
  fi
  # wait for vpn to start
  echo "vpn $VPN started:$GW_VPN"
  sleep 30
  return 0
}

function stop_vpn() {
  echo  -e '\t**' "stop $VPN"
  /usr/local/bin/lxc-stop -n $VPN
  if [ $? ]; then
    if [ -n $PID ];then
        sleep 5
	if kill -0 $PID; then kill $PID;fi
	ALL_PIDS=$(ps -ef | grep "/usr/local/bin/lxc-start -n $VPN" | grep -v grep | gawk '{print $2}')
	if [ -n $ALL_PIDS ];then
	    kill -9 $ALL_PIDS
	    sleep 5
	fi
    fi
  fi
  return $?
}

LXCVPNS=$(ls /usr/local/var/lib/lxc)
ALL=( ${LXCVPNS[@]} ${ALL[@]} )
