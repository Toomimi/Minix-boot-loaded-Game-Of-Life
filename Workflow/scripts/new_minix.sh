#!/bin/bash
qemu-img create -f qcow2 -F raw -o backing_file=../.minix_image/minix.img minix.img   
qemu-system-x86_64 -curses -drive file=minix.img -rtc base=localtime -net user,hostfwd=tcp::15881-:22 -net nic,model=virtio -m 1024M -enable-kvm
