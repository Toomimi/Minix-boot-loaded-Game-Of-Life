# Minix Game-Of-Life boot loader modification

This project is a modification of default Minix bootloader, such that before loading the system, boot loader displays Game Of Life on 24x80 torus. Game of life starts with begining state P and generations change with delay N, where N and P are provided during instalation. Simulation runs until user presses any button, while pressed, default boot loader is restored.

### How to run?
- Launch minix (Qemu worked for me)
- copy files from this repo to minix
- run make
- run install.sh <P> <N>
  - **P**: one line file of length 1920 (24*80) where **#** indicates alive cell and **space** a dead one. (Look examples)
  - **N**: 0...255 integer being a delay time (system clock ticks) between generations 

### Minix launch
This repo includes also my workflow scripts for running Minix, but it requieres having the minix.img as a back-up file.
