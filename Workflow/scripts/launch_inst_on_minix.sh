#!/usr/bin/expect
spawn ssh minix
expect "password"
send "root\r"
expect "# "
send "./install.sh\r"
send "^c"
interact
