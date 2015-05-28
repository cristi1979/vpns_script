#PASS_FILE="/media/share/Documentation/cfalcas/q/vpns_script/vpns_web/extra/pass_pelephone"
PASS_FILE="/var/log/mind/vpn/extra/pass_rdp"

function get_password_from_web_file {
    count=120
    # no old pass:
    rm -f "$PASS_FILE"
    echo "waiting 2 minutes for a new password..."
    PASS=""
    while [[ $count -ne 0 ]] ; do
	sleep 1
	if [[ -f "$PASS_FILE" ]];then
	    PASS=$(cat "$PASS_FILE");
	    if [[ -z "$PASS" ]];then
		echo empty password
	    else
		echo "found pass = " $PASS
		count=1
	    fi
	else 
	    echo "no pass yet. $count"
	fi
	((count = count - 1))
    done
    rm -f "$PASS_FILE"
    if [[ -z "$PASS" ]];then
	echo no pass retrieved
	return 1
    else 
	echo using pass $PASS
	sed -i s/"^.*Xauth password.*$/Xauth password $PASS"/ "$VPNC_CONF_DIR/$VPN.conf"
        return $?
    fi
}

function get_password_from_rdc() {
    Xvfb $DISPLAY -screen 0 1024x768x16 &
    echo -e "\t** open background display"
    sleep 2
    rdesktop 10.0.4.193 -u administrator -p tester &
    sleep 2
    WINID=$(xdotool search --name "rdesktop - 10.0.4.193")
    echo -e "\t** Got WINID: $WINID"
    xdotool key --window $WINID "Escape"
    xdotool key --window $WINID "Return"
    sleep 2
    echo -e "\t** connected to RDP"
    #xdotool key --window $WINID "Escape"
    #sleep 2
    #xdotool key --window $WINID "super+r"
    #sleep 2
    #echo "\"C:\Program Files\RSA Security\RSA SecurID Software Token\SecurID.exe\"" | xclip -i
    #sleep 2
    #xdotool key --window $WINID "Ctrl+v"
    #xdotool key --window $WINID "Alt+Tab"
    xdotool keydown --window $WINID "Alt_L" && xdotool key --window $WINID "Tab" && xdotool keyup --window $WINID "Alt_L" 
    #sleep 1
    xdotool type --delay 1000 --window $WINID "3338"
    sleep 1
    xdotool key --window $WINID "Return"
    sleep 2
    echo -e "\t** generate password"
    xdotool key --window $WINID "Alt+c"
    PASS=$(xclip -o)
    echo -e "\t** copy password: $PASS"
    kill $(ps -ef | grep "rdesktop 10.0.4.193" | grep -v grep | gawk '{print $2}')
    if [ -z "$PASS" ]; then
	echo -e "\tEE Could not retrieve password.\n"
	return 1
    fi
    sed -i s/"^.*Xauth password.*$/Xauth password $PASS"/ "$VPNC_CONF_DIR/$VPN.conf"
    return $?
}
