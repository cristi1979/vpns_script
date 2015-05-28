#!/usr/bin/expect --
set timeout 30
set machine [lindex $argv 0]
if {  $::argc > 1 } {set port [lindex $argv 1]} else {set port 3389}

spawn xfreerdp $machine:$port
expect {
  "connected to" {exit 0}
  timeout { exit 2}
}
exit 3
