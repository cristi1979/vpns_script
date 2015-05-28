#!/bin/bash
###files are in customers
##must contain at least TYPE
###ex:
##TYPE=CISCO
##IP=(10.0.20.43 10.0.20.4)
##ROUTE=()
##REM_ROUTE=()
##ALIVE="ssh" - ssh or ping

START=1
DISPLAY=20
export DISPLAY=:$DISPLAY
LOG_DIR="/var/log/mind/vpn/"
LOG_PREFIX="$LOG_DIR/logs/output_vpn"
MY_DIR=$(dirname $(readlink -f $0))
CUSTOMERS_DIR="$MY_DIR/customers"
VPN_TYPES_DIR="$MY_DIR/vpntypes"
mkdir -p "/var/run/mind/"
mkdir -p "$LOG_DIR/logs/"
mkdir -p "$LOG_DIR/status/"
PID_FILE="/var/run/mind/mind_vpn.pid"
TIMESTAMP_FILE="/var/run/mind/mind_vpn.timestamp"
CRT_DATE=$(date -u +%s)

if ! [ -d $CUSTOMERS_DIR -a -d $VPN_TYPES_DIR -a $PID_FILE ];then
  echo -e '\t**' "define customers dir, vpn types and/or pid file";
  exit 1;
fi

ME="$0"
MY_PID=$$
OLD_ME="$(ps $(cat $PID_FILE 2> /dev/null) | grep -v 'PID TTY      STAT   TIME COMMAND')"
declare -a ALL
DEV_DEF=$(ip route | grep ^default | sed 's/^.* dev \([[:alnum:]_-]\+\).*$/\1/' | head -1)
#'
GW_DEF=$(ip route | grep ^default | cut -d " " -f 3 | head -1)
#MCABLE
#iptables -t nat -D POSTROUTING -d 200.52.193.0/24 -o $DEV_DEF -j MASQUERADE
#iptables -t nat -I POSTROUTING -d 200.52.193.0/24 -o $DEV_DEF -j MASQUERADE
#TELEM
#iptables -D PREROUTING -t nat -i eth6 -p tcp --dport 13389 -j DNAT --to 172.16.32.30:3389
#iptables -I PREROUTING -t nat -i eth6 -p tcp --dport 13389 -j DNAT --to 172.16.32.30:3389
#iptables -D PREROUTING -t nat -i eth6 -p tcp --dport 10080 -j DNAT --to 172.16.32.40:80
#iptables -I PREROUTING -t nat -i eth6 -p tcp --dport 10080 -j DNAT --to 172.16.32.40:80

function includes() {
  for i in $(ls $VPN_TYPES_DIR/);do
    . $VPN_TYPES_DIR/$i
  done
}

function is_alive_ssh() {
    IP=$1
    PORT=$2
    if [ ! $PORT ];then PORT=22;fi
    echo -e '\t**' "Testing ssh to $IP, port $PORT"
    OUTPUT="$(ssh -o ConnectTimeout=30 -o BatchMode=yes -o ServerAliveInterval=5 -o ServerAliveCountMax=5 $IP -p $PORT 2>&1 >/dev/null | tail -1)"
    echo -e '\t**' "done ssh to $IP"
    NOK1="ssh: connect to host $IP port 22: Connection timed out"
    NOK2="Connection to $IP timed out while waiting to read"
    OK1="Permission denied"
    OK2="Host key verification failed."
    OK3="Connection timed out during banner exchange"
    if [[ "$OUTPUT" =~ $OK1 || "$OUTPUT" =~ $OK2 || "$OUTPUT" =~ $OK3 ]]; then
	echo -e '\t**' "ssh to $IP finished ok"
	return 0
      elif [[ "$OUTPUT" =~ "$NOK1" || "$OUTPUT" =~ "$NOK2" ]]; then
        echo -e '\tEE' "ssh to $IP finished with error"
	return 1
      else
	echo -e '\tEE' "Uknown error for ssh to $IP."
	echo -e '\tEE' "Output was: $OUTPUT"
	echo -e '\tEE' "We where waiting for: $OK"
	return 2
    fi;
}

function is_alive_rdp() {
    IP=$1
    PORT=$2
    echo -e "\t** test ip $IP port $PORT with $ALIVE"
    "$MY_DIR/tools/test_rdp.tcl" $IP $PORT
    if [ $? -eq 0 ];then
	echo -e '\t**' "RDP to $IP port $PORT was OK"
	return 0
    else 
	echo -e '\t**' "RDP to $IP port $PORT  has failed"
	return 1
    fi
}

function is_alive_ping() {
    IP=$1
    echo -e '\t**' "Testing ping to $IP"
    ping $IP -c 3 -w 10 1>&2 > /dev/null
    if [ $? -eq 0 ];then
	echo -e '\t**' "Ping to $IP was OK"
	return 0
    else 
	echo -e '\t**' "Ping to $IP has failed"
	return 1
    fi
}

function is_alive() {
  IP=$1
  IP_PORT_ARR=(${IP//:/ })
  IP=${IP_PORT_ARR[0]}
  PORT=${IP_PORT_ARR[1]}
  if [ ${IP_PORT_ARR[2]} ];then ALIVE=${IP_PORT_ARR[2]}; fi
  if [ $ALIVE -a $ALIVE == "ssh" ]; then
    is_alive_ssh $IP $PORT
  elif [ $ALIVE -a $ALIVE == "rdp" ]; then
    is_alive_rdp $IP $PORT
  else
    is_alive_ping $IP
  fi
}

function test_vpn() {
  echo -e '\t**' "testing $VPN"
  if [ -z "$CMD" ];then
    echo -e '\tEE' "no command for $VPN"
    return 300
  else
    for i in ${IP[@]};do
	is_alive $i &
    done;
    SUCCESS=1
    for pid in $(jobs -p); do 
	if [ $SUCCESS -eq 0 ];then
	    kill -9 $pid 2> /dev/null
	else
    	    wait $pid && SUCCESS=$?
    	fi
    done
    return $SUCCESS
  fi
}

function firewall_vpn() {
  ##$1 - I/D
  if [ $VPN_TYPE == "lxc" -o $VPN_TYPE == "juniper_lxc" ];then
    return 0
  fi
  echo -e '\t**' "Setting firewall to $1 for $VPN"
  TYPE=$1
  if [ $TYPE == "I" -o $TYPE == "D" -a "$DEV_VPN" ];then
    iptables -t nat -$TYPE POSTROUTING -o $DEV_VPN -j MASQUERADE
    iptables -$TYPE FORWARD -i $DEV_VPN -o $DEV_DEF -m conntrack  --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -$TYPE FORWARD -i $DEV_DEF -o $DEV_VPN -j ACCEPT
    ### take care of logging
    ##### forward
    #echo -e "\t** fix forward firewall: $TYPE"
    #iptables -D FORWARD -p udp -j ACCEPT
    #iptables -D FORWARD -p icmp -j ACCEPT
    #iptables -D FORWARD ! -d 10.0.0.99 ! -s 10.0.0.99 -j LOG --log-prefix "iptables: FORWARD filter " \
#	--log-level 7 --log-tcp-sequence --log-tcp-options --log-ip-options -m limit --limit 600/minute
    ##
    #iptables -I FORWARD ! -d 10.0.0.99 ! -s 10.0.0.99 -j LOG --log-prefix "iptables: FORWARD filter " \
#	--log-level 7 --log-tcp-sequence --log-tcp-options --log-ip-options -m limit --limit 600/minute
    #iptables -I FORWARD -p udp -j ACCEPT
    #iptables -I FORWARD -p icmp -j ACCEPT
    ##### POSTROUTING
    #echo -e "\t** fix post firewall: $TYPE"
    #iptables -t nat -D POSTROUTING -p udp -j ACCEPT
    #iptables -t nat -D POSTROUTING -p icmp -j ACCEPT
    #iptables -t nat -D PREROUTING -p icmp -j ACCEPT
    #iptables -t nat -D POSTROUTING ! -d 10.0.0.99 ! -s 10.0.0.99 -j LOG \
#	 --log-prefix "iptables: POST nat " --log-level 7 --log-tcp-sequence \
#	  --log-tcp-options --log-ip-options -m limit --limit 60/minute
    ##
    #iptables -t nat -I POSTROUTING ! -d 10.0.0.99 ! -s 10.0.0.99 -j LOG \
#	 --log-prefix "iptables: POST nat " --log-level 7 --log-tcp-sequence \
#	  --log-tcp-options --log-ip-options -m limit --limit 60/minute
    #iptables -t nat -I POSTROUTING -p udp -j ACCEPT
    #iptables -t nat -I POSTROUTING -p icmp -j ACCEPT
    #iptables -t nat -I PREROUTING -p icmp -j ACCEPT
  else
    echo -e '\tEE' "For firewall we need I/D. We got _$1_"
  fi
}

function route_vpn() {
  ##$1 - add/del
  echo -e '\t**' "Setting routes to $1 for $VPN"
  TYPE=$1
  ip route del default dev $DEV_VPN
  if [ $? -gt 0 ];then
    echo -e '\tEE' "error for ip route del default dev $DEV_VPN"
  fi
  ip route del default dev $DEV_DEF
  if [ $? -gt 0 ];then
    echo -e '\tEE' "error for ip route del default dev $DEV_DEF"
  fi
  ip route add default via $GW_DEF dev $DEV_DEF
  if [ $? -gt 0 ];then
    echo -e '\tEE' "error for ip route add default via $GW_DEF dev $DEV_DEF"
  fi

  if [ $TYPE == "add" -o $TYPE == "del" -a "$DEV_VPN" ];then
    for i in ${ROUTE[@]};do
      echo -e '\t**' route $i
      CRT_USED_DEV_VPN=$(ip route show | grep $i | cut -f 3 -d \ )
      CRT_USED_ROUTE=$(ip route show | grep $i)
      if [ "$CRT_USED_DEV_VPN" != "$DEV_VPN" -a $TYPE == "del" -a "$CRT_USED_ROUTE" != "" -a $VPN_TYPE != "lxc" -a $VPN_TYPE != "juniper_lxc" ]; then
	echo -e '\tEE' "route $i seems to use device $CRT_USED_DEV_VPN with route $CRT_USED_ROUTE, but we should have $DEV_VPN;"
	ip route del $CRT_USED_ROUTE
      fi

      VIA=""
      EXTRA=""
      if [ $VPN_TYPE == "lxc" -o $VPN_TYPE == "juniper_lxc" -a $TYPE == "add" ];then
	  #ip route $TYPE $i via $GW_VPN dev $DEV_VPN onlink
	  VIA="via $GW_VPN"
	  EXTRA="onlink"
      elif [ $VPN_TYPE == "dummy" -a $TYPE == "add" ];then
	  VIA="via $GW_VPN"
      fi
      echo -e '\t**' "Set route to: ip route $TYPE $i $VIA dev $DEV_VPN $EXTRA"
      ip route $TYPE $i $VIA dev $DEV_VPN $EXTRA
      if [ $? -gt 0 ];then
        echo -e '\tEE' "error for ip route $TYPE $i $VIA dev $DEV_VPN $EXTRA;"
      fi
    done                 	
  else
    echo -e '\t**' "For routes we need add/del. We got _$1_"
  fi
  for i in ${REM_ROUTE[@]};do
    ip route del $i dev $DEV_VPN;
    if [ $? -gt 0 ];then
      echo -e '\tEE' "error for ip route del $i dev $DEV_VPN;"
    fi
  done
}

function start_connection() {
  CUST_FILE_PATH=$CUSTOMERS_DIR/$1
  if [ -f $CUST_FILE_PATH ];then
    echo "========================= START ========================="
    echo '**' "All customers: ${ALL_VPNS[@]}"
    echo "========================================================="
    echo "-------------- $(date) Check $customer -----------"

    ##import customer data IP, TYPE...
    . $CUSTOMERS_DIR/null
    echo -e "\t XXX incarca " $CUSTOMERS_DIR/null TYPE=${TYPE[@]} IP=${IP[@]} ROUTE=${ROUTE[@]} \
	    REM_ROUTE=${REM_ROUTE[@]} ALIVE=${ALIVE[@]} RETRIES=${RETRIES[@]}
    . $CUST_FILE_PATH;
    TYPE=$(echo $TYPE | tr "[:upper:]" "[:lower:]")
    echo -e "\t XXX incarca " $CUST_FILE_PATH TYPE=${TYPE[@]} IP=${IP[@]} ROUTE=${ROUTE[@]} \
	    REM_ROUTE=${REM_ROUTE[@]} ALIVE=${ALIVE[@]} RETRIES=${RETRIES[@]}
    VPN_TYPE=$TYPE
    VPN_FILE=$(readlink -f $(find $VPN_TYPES_DIR -iname $VPN_TYPE".sh"))
    if [ -f $VPN_FILE ];then
      ##import vpn type functions set_variables, start, stop
      . $VPN_FILE
      set_variables $1
      echo -e "\t##vpn name: "$VPN
      echo -e "\t##vpn type: "$VPN_TYPE
      echo -e "\t##gw "$GW_VPN
      echo -e "\t##dev "$DEV_VPN
      echo -e "\t##pid "$PID
      echo -e "\t##cmd "$CMD
      echo -e "\t##ips to check: "${IP[@]}

      FAILED_NR=$(cat "$CUSTOMERS_DIR/failed_retries" | grep ^$VPN= | sed s/^$VPN=// | head -1)
      if [ -z "$FAILED_NR" ]; then
        echo "$VPN=0" >> "$CUSTOMERS_DIR/failed_retries"
      fi
      FAILED_NR=$(($FAILED_NR + 0 ))
      echo -e "\t##max failed attempts: $RETRIES, already failed: $FAILED_NR"
      if [ $FAILED_NR -ge $RETRIES ]; then
        echo -e "\tEE max failed attempts reached: tried $RETRIES times and we have max $FAILED_NR retries"
        echo '========================= END ========================='
        return
      fi

      test_vpn
      RET=$?
      #echo $(date +%s) $RET >> "$LOG_DIR/status/$VPN"_$(date +%Y%m%d)
      echo -e '\t**' "return code from $1 is $RET"
      if [ $RET -gt 0 ];then
	##seems we have the command running, but the connection is down
	if [ $PID ];then
	  echo -e '\t**' "Interface up, network down for $VPN";
	else
          echo -e '\tEE' "this is strange. We have the command: $CMD, but pid _$PID\_ seems to be missing. Process line is $PROC."
	fi
	FAILED_NR=$(($FAILED_NR + 1 ))
        sed -i s/^$VPN=\[0-9\].*$/$VPN=$FAILED_NR/ "$CUSTOMERS_DIR/failed_retries"
	echo -e '\t**' "VPN $VPN down, setting failed retries to $FAILED_NR.";

	firewall_vpn D
	route_vpn del
	stop_vpn
	sleep 5
	start_vpn
	if [ $? -eq 0 ];then
	  set_variables $1
	  sleep 1
	  firewall_vpn I
	  route_vpn add
          test_vpn && sed -i s/^$VPN=\[0-9\].*$/$VPN=0/ "$CUSTOMERS_DIR/failed_retries" && echo $(date -u +%s) > "$LOG_DIR/status/$VPN"
	else
	  echo -e '\tEE' "Can't start vpn $VPN"
	fi
      else
	echo -e '\t**' "VPN $VPN is up.";
        sed -i s/^$VPN=\[0-9\].*$/$VPN=0/ "$CUSTOMERS_DIR/failed_retries"
	firewall_vpn D
	firewall_vpn I
      fi
    fi

    echo '========================= END ========================='
  fi
}

function stop_connection() {
  CUST_FILE_PATH=$CUSTOMERS_DIR/$1
  if [ -f $CUST_FILE_PATH ];then
    ##import customer data IP, TYPE...
    . $CUSTOMERS_DIR/null
    . $CUST_FILE_PATH;
    TYPE=$(echo $TYPE | tr "[:upper:]" "[:lower:]")
    VPN_FILE=$(readlink -f $(find $VPN_TYPES_DIR -iname $TYPE".sh"))
    if [ -f $VPN_FILE ];then
      ##import vpn type functions set_variables, start, stop
      . $VPN_FILE
      set_variables $1
      echo -e "\t##vpn name: "$VPN
      echo -e "\t##vpn type: "$TYPE
      echo -e "\t##gw "$GW_VPN
      echo -e "\t##dev "$DEV_VPN
      echo -e "\t##pid "$PID
      echo -e "\t##cmd "$CMD
      echo -e "\t##ips to check: "${IP[@]}
      firewall_vpn D
      route_vpn del
      stop_vpn
    fi
  fi
}

if [ "$1" == "-test" ];then
    CMD="ls /dev/null"
    if [ ! -f $CUSTOMERS_DIR/$2  -o $2 == "null" ];then exit 100;fi
    . $CUSTOMERS_DIR/null
    . $CUSTOMERS_DIR/$2
    if [ $TYPE == "dummy" ];then exit 100;fi
    test_vpn
    exit $?
fi

if [ "$1" == "-stop" ];then
  ALL=()
  includes
  NR=${#ALL[@]}
  ALL_VPNS=(${ALL[@]})
  kill -9 $(echo $OLD_ME | cut -d " " -f 1)
  for i in ${ALL_VPNS[@]};do
    LOG_FILE="$LOG_PREFIX"_"$i"
#    echo "-------------- $(date) Stopping $i -----------" &>> "$LOG_FILE"
        echo "-------------- $(date) Stopping $i -----------"
    stop_connection $i &>> $LOG_FILE &
    mv $LOG_FILE $LOG_FILE.old
  done
  for pid in $(jobs -p); do wait $pid && echo "done $pid"; done
  systemctl restart iptables network
  START=0
fi

ip route add default via 10.0.0.1
### I have my pid file AND OLD_ME is not dead
if [ -e $PID_FILE -a -n "$OLD_ME" ];then
  #echo -e '\t**' "me, already running" >&2
  echo -e '\t**' "me, already running" > /dev/null
  LAST_DATE_UPDATE=$(cat $TIMESTAMP_FILE)
  let DIF=$CRT_DATE-$LAST_DATE_UPDATE
  if [[ $DIF -gt 300 ]];then 
    echo -e '\t**' "me, already running, but not kicking anymore: \
	now is $CRT_DATE and last time was $LAST_DATE_UPDATE. Please kill me." 1>&2
    kill -9 $(echo $OLD_ME | cut -d " " -f 1)
  fi
else
  echo -e '\t **' "we are dead, start again:"
  echo $MY_PID > $PID_FILE

  while [ $START -eq 1 ];do
    CRT_DATE=$(date -u +%s)
    rm -rf /etc/resolv.conf
    cp /etc/resolv.conf.good /etc/resolv.conf
    rm -rf /etc/hosts
    cp /etc/hosts.good /etc/hosts
    ALL=()
    includes
    NR=${#ALL[@]}
    #ALL_VPNS=(${ALL[@]})
    readarray -t ALL_VPNS < <(printf '%s\n' "${ALL[@]}" | sort)
    ##for all customers
    for customer in ${ALL_VPNS[@]};do
      echo $CRT_DATE > $TIMESTAMP_FILE
      echo $customer > "$LOG_PREFIX"_now_testing
      LOG_FILE="$LOG_PREFIX"_$customer
      start_connection "$customer" &>> "$LOG_FILE"
    done
    #for pid in $(jobs -p); do wait $pid && echo "done $pid"; done
  done
fi
