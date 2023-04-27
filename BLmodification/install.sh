#!/usr/bin/env bash

BL_NAME='game_of_life_bl.o'
# copy partition table to modified BL
dd bs=16 count=5 skip=27 seek=27 if=/dev/c0d0 of=$BL_NAME

# copy Minix boot loader. It will be saved on second sector 
dd bs=512 count=1 seek=1 if=/dev/c0d0 of=$BL_NAME
echo 'Appended modified BL with default Minix BL '

# save delay between state change
printf \\$(printf '%03o' $2) >> $BL_NAME
printf \\$(printf '%03o' 0) >> $BL_NAME
echo 'Appeneded modified BL with delay constant'

# save game of life state from file
dd bs=1920 count=1 if=$1 >> $BL_NAME
echo 'Appended modified BL with file P'

# 2*512: modified and default BL, 2: delay constant, 1920: P file size
BLOCK_SIZE=$((2 * 512 + 2 + 1920)) 
# Copy whole modified BL with appened data to /dev/c0d0
dd bs=$BLOCK_SIZE count=1 if=$BL_NAME of=/dev/c0d0
echo 'Swapped default Minix BL for modified with appended data'
