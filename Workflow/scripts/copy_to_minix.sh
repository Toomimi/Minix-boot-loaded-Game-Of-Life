#!/usr/bin/expect
spawn nasm -f bin modified_boot_loader.asm -o to_copy/my_bl
spawn scp -P 15881 to_copy/diff.sh to_copy/my_bl to_copy/install.sh to_copy/test_file root@localhost:/root/
expect "password"
send "root\r"
interact
