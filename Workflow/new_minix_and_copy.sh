kill $(ps aux | grep 'qemu' | awk '{print $2}')
gnome-terminal --geometry=115x40 -- ./scripts/new_minix.sh
sleep 2
./scripts/copy_to_minix.sh
gnome-terminal --tab -- ./scripts/launch_inst_on_minix.sh 
sleep 3
kill $(ps aux | grep 'launch_inst_on_minix.sh' | awk '{print $2}')

