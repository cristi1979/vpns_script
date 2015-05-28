CRT_DIR=$(dirname $0)
DISPLAY=14
#DISPLAY=1023

function start() {
    echo -e '\t  *'  "============================================"
    echo -e '\t  *   Staring...'
    clean
    background
    #live
}

function stop(){
    echo -e '\t  *   Stopping'
    clean
}

function clean(){
 echo -e '\t  *'   "Cleaning up."
 #xpra stop
 killall -9 firefox
 killall -9 firefox-bin
 killall -9 ruby
 killall -9 java
 killall -9 java-vm
 killall -9 ncsvc
 killall -9 Xvfb
 killall -9 fluxbox
 rm -rf ~/.mozilla/firefox/*/Cache/*
 rm -f /tmp/.X$DISPLAY-lock
}

function live(){
 export DISPLAY=:$DISPLAY
 fluxbox > /dev/null 2>&1 &
 echo -e '\t  *'   "Starting browser in display $DISPLAY."
 sleep 5
 echo -e '\t  *'   "Starting ruby script."
 ruby $CRT_DIR/$CUST.rb
}

function background(){
 echo -e '\t  *'   "Stoping already existing X."
 killall -9 Xvfb
 rm -f /tmp/.X$DISPLAY-lock
 echo -e '\t  *'   "Start new background X."
 Xvfb :$DISPLAY -screen 0 1024x768x16 -fbdir /tmp &
 sleep 2
 live
}

CUST=$2

case $1 in
    -start)
        start
    ;;
    -stop)
        stop
    ;;
    *)
        echo Use like: "$0 -start|-stop";
        exit
esac

exit
