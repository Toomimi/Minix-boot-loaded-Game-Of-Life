#!/bin/bash
qemu-system-x86_64 -curses -drive file=minix.img -rtc base=localtime -net user,hostfwd=tcp::15881-:22 -net nic,model=virtio -m 1024M -enable-kvm