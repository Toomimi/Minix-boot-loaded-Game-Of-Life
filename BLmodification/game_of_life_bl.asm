[bits 16]
[org 0x0600]

;--------------------------------Constants' definitions-------------------------------
N                  equ 0x7e00
STATE_ADDRESS      equ 0x7e00 + 2
STATE_COPY_ADDRESS equ 0x9000

LU_CORNER   equ 0
RU_CORNER   equ 79
LD_CORNER   equ 23 * 80
RD_CORNER   equ 23 * 80 + 79

HASH_ASCII  equ 35
SPACE_ASCII equ 32
;------------------------------Constats' definitions end------------------------------

;----------------------------------Start of the code----------------------------------
start:
  cli                     ; block interrutions calls
  xor ax, ax              ; 0 AX
  mov ds, ax              ; set Data Segment to 0
  mov es, ax              ; set Extra Segment to 0
  mov ss, ax              ; set Stack Segment to 0
  mov sp, ax              ; set Stack Pointer to 0
  
  ; copy current code lower, to leave space for default Minix BL
  mov cx, 0x0100          ; Copying 256 words (512B)
  mov si, 0x7C00          ; Current MBR Address
  mov di, 0x0600          ; New MBR Address
  rep movsw               ; Copy MBR
  jmp 0:lowStart          ; Jump to next instruction of this code    
  ; LowStart label is based on org 0x0600 - place where copied code is

lowStart:                 ; coppied MBR code
  sti                     ; unblock interruptions' calls
  mov  ah, 0x02           ; choose interruption function (write sectors)
  mov  al, 0x09           ; sectors to read 1-minix BL, 4-data, 5-zeros to restore
  mov  cl, 0x02           ; from which sector we start reading (starts from 1) 
  mov  bx, 0x7c00         ; Place where we want to load sectors
  call access_disk_sectors_interruption  

  ; write state from 4 loaded at STATE_ADDRESS sectors
  call print_state

  push dx                 ; save DL value - disk id
  
  ; save current actual clock ticks count
  mov  ah, 0x00           ; choose interruption function (Read RTC)
  int  0x1a               ; interruption 1Ah call - Real Time clock services
  ; based on CX:DX saves actual clock ticks count + N to SI:DI
  call save_to_si_di_actual_time

; loop to check time, update state and get keyboard input
.check_clock:
  call check_time_and_calculate_and_print_new_state_if_needed
  call check_for_keyboard_input   ; returns CL != 0 when input occured   
  test cl, cl                     ; check if CL == 0
  jz   restore_minix_state        ; if input occured, restore minix state
  jmp  .check_clock               ; again, check if enough clock ticks occured

restore_minix_state:
  pop  dx                 ; restore DL value - disk id 

  ; overwrite 1st disk sector with default Minix BL  
  mov  ah, 0x03           ; choose interruption function (write sectors)
  mov  al, 0x01           ; sectors to write 1 
  mov  cl, 0x01           ; writing on the first sector
  mov  bx, 0x7c00         ; address we take code from (coppied earlier)
  call access_disk_sectors_interruption 
  
  ; clear, with earlier coppied zeros, sectors 2-6, modified by install.sh 
  mov  ah, 0x03           ; choose interruption function (write sectors)
  mov  al, 0x05           ; sectors to write 5
  mov  cl, 0x02           ; we clear from sector 2 (numeration starts from 1)
  mov  bx, 0x8600         ; address where zeros are currently stored
  call access_disk_sectors_interruption
  ; Disk state before install.sh is restored
  
  ; Jump to default minix boot loader
  jmp  0:0x7c00 

;----------------------------------End of main code----------------------------------

;-------------------------------Functions' declarations-------------------------------

; Calls an 13h interruption for cylinder and head id set to 0
; Assumes DL stores disk id and other parameters are set before call
; Modifies CH, DH     Requiers to be set: AH, AL, CL, BX 
access_disk_sectors_interruption:
  mov  ch, 0x00           ; cylinder id
  mov  dh, 0x00           ; head id
  int  0x13               ; Interruption 13h call - low level disk services
  ret

; Sets cl to non-zero value when keyboard key was pressed
; Modifies: CL, AX
check_for_keyboard_input:
  xor  cl, cl             ; set CL to 0
  mov  ah, 0x01           ; choose interruption function (read input status)
  int  0x16               ; interruption 16h call - keyboard services
  setz cl                 ; set CL to non-zero value if any key in buffer
  ret

; Check if N clock counts passed and if passed,
; calculates and prints new state. Stores clock count + N in SI:DI
; Modifies: SI, DI, CX, DX, AH    (not directly): BX
; Assumes SI:DI will store previous clock count + N
check_time_and_calculate_and_print_new_state_if_needed:
  mov  ah, 0x00           ; choose interruption function (Read RTC)
  int  0x1a               ; interruption 1Ah call - Real Time clock services
  ; Check if N clock ticks occured
  cmp si, cx  
  jb  .time_passed        ; occured
  cmp di, dx
  jbe .time_passed        ; occured
  ret                     ; didn't occur

.time_passed: 
  ; based on CX:DX saves actual clock ticks count + N to SI:DI
  call save_to_si_di_actual_time

  push si                 ; retain SI and DI values  
  push di

  call update_state       ; modifies: SI, DI, CX, AX, BX
  call print_state        ; modifies: SI, AX

  pop  di                 ; restore SI and DI values
  pop  si
  ret

; Rewrites CX:DX + N to SI:DI 
; Modifies:  SI, DI   Reads: CX, DX 
save_to_si_di_actual_time:
  add dx, [N]             ; add N to actual clock ticks
  adc cx, 0               ; add carry if N didn't fit 
  mov si, cx              ; rewrite to CX:DX to SI:DI
  mov di, dx
  ret  

;-------------------------------State update functions--------------------------------

; Counts next generation of Game of life,
; Modifies: SI, DI, CX    (not directly): AX, BX
update_state:
  ; copy current state for reference
  mov  cx, 0x0780             ; state is 1920b string 
  mov  si, STATE_ADDRESS      ; current address
  mov  di, STATE_COPY_ADDRESS ; new address
  rep  movsb  

  call update_cells           ; update state of each cell
  ret

; Updates state of each cell, iterates over state using 2 indexes:
; DI - row number (i), SI - column number (j).
; Modifies:  SI, DI       (not directly): CX, AX, BX
update_cells:
  xor  di, di             ; Set i to 0 (first row)
.next_row:
  xor  si, si             ; Set j to 0 (first cell of the row)
.next_cell:
  call alive_neigh_count  ; count alive neighbours of cell (saves in CX)
  call update_cell_state  ; update cell state  using CX value
  
  inc  si                 ; next cell in a row
  cmp  si, 80             ; check if row is parsed
  jne  .next_cell
  inc  di                 ; row is parsed, next row
  cmp  di, 24             ; check if fnished
  jne  .next_row
  ret

;--------------------------Alive neighbour count functions----------------------------

; Count alive neighbours for DI*80 + SI cell
; Arguments: DI row number (i), SI column number (j)
; Returns:   CX - alive neigbours count
; Modifies:  CX           (not directly): AX, BX
; Assumes calls from it, won't change DI and SI (mod is an exception)
alive_neigh_count:
  push di                         ; retain DI (row number)
  xor  cx, cx                     ; set CX, neighbour counter to 0

  call add_alive_next_and_before  ; adding for (i, j - 1), (i, j + 1)

  inc  di
  call mod24
  call add_if_alive_cell          ; adding for (i + 1, j)
  call add_alive_next_and_before  ; adding for (i + 1, j - 1), (i + 1, j + 1)

  sub  di, 2
  call mod24
  call add_if_alive_cell          ; adding for (i - 1, j)
  call add_alive_next_and_before  ; adding for (i - 1, j - 1), (i - 1, j + 1)

  pop  di                         ; restore DI (row number)
  ret

; Increments CX for each alive cell from (i, j + 1) 
; Arguments: DI row number (i), SI column number (j), CX alive neighbour count
; Modifies:  CX           (not directly): AX, BX 
add_alive_next_and_before:
  push si                 ; retain SI (column number)
  inc  si
  call mod80
  call add_if_alive_cell  ; adding for (i, j + 1)
  
  sub  si, 2
  call mod80
  call add_if_alive_cell  ; adding for (i, j - 1)
  pop  si                 ; restore SI (column number)
  ret

; Increments CX if cell (i,j) is alive.
; Arguments: DI row number (i), SI column number (j), CX alive neighbour count
; Modifies:  CX                    (not directly): AX
add_if_alive_cell:
  call count_and_save_offset_to_bx
  cmp  byte [STATE_COPY_ADDRESS + bx], HASH_ASCII  ; check if cell is alive
  jne  .return            ; cell is dead, skip incrementation
  inc  cx                 ; cell is alive, increment counter
.return: 
  ret

;-----------------------End of alive neighbour count functions------------------------

; Based on alive neighbour count funciton revives or kills a cell.
; Arguments: DI row number (i), SI column number (j), CX alive neighbour count
; Modifies:  BX                    (not directly): AX
update_cell_state:   
  call count_and_save_offset_to_bx
  ; update state
  cmp  byte [STATE_ADDRESS + bx], HASH_ASCII   ; check if alive
  jne  .dead_cell
; alive_cell
  cmp  cx, 3
  je  .return             ; cell has 3 alive neighbours - remains alive
  cmp  cx, 2
  je   .return            ; cell has 2 alive neighbours - remains alive
  mov  byte [STATE_ADDRESS + bx], SPACE_ASCII  ; kill a cell
  ret 
.dead_cell:
  cmp  cx, 3
  jne  .return            ; alive neighbour counter != 3 - remains dead
  mov  byte [STATE_ADDRESS + bx], HASH_ASCII   ; revive a cell
.return:
  ret

;---------------------------End of State update functions-----------------------------

;--------------------------State update auxiliary functions---------------------------

; Counts offset, i * 80 + j, and saves it to BX.
; Arguments: DI row number (i), SI column number(j)
; Modifies AX, BX
count_and_save_offset_to_bx:
  mov ax, 80
  mul di            ; AX: i * 80
  mov bx, ax
  add bx, si        ; BX: i * 80 + j
  ret

; Counts DI mod 24 and saves result to DI.
; Arguments: DI row number (i)
; Modifies:  DI, AX, BX
mod24:
  mov   ax, di      ; save dividend
  mov   bl, 24      ; save divisor
  idiv  bl          ; stores remainder in AH
  test  ah, ah      ; check if remainer is signed
  jns   .not_signed
  add   ah, 24      ; add 24, to get mod value
.not_signed: 
  movsx di, ah      ; rewrite result to DI
  ret

; Counts SI mod 80 and saves result to SI.
; Arguments: SI column number (j)
; Modifies:  SI, AX, BX
mod80:
  mov   ax, si      ; save dividend
  mov   bl, 80      ; save divisor
  idiv  bl          ; stores remainder in AH
  test  ah, ah      ; check if remainder is signed
  jns   .not_signed
  add   ah, 80      ; add 80, to get mod value
.not_signed: 
  movsx si, ah      ; rewrite result to SI
  ret

;----------------------End of state update auxiliary functions------------------------


; Writes to screen current state saved under STATE_ADDRESS.
; Modifies: AX, SI 
print_state:
  mov  si, STATE_ADDRESS  ; save to SI state_address
  mov  ah, 0x0e           ; choose interrupt function (put char and move cursor)
.print:
  mov  al, byte [si]      ; argument for interruption call - char to write
  test al, al
  jz   .finish_print      ; if next char has 0x00 code (null char), stop
  int  0x10               ; interruption 10h call - video services 
  inc  si                 ; increment address, to get next letter
  jmp  .print
.finish_print:
  ret

;---------------------------End of functions' declarations----------------------------


times 510-($-$$) db 0     ; fill MBR with 0x00 to 510 bytes
dw 0xAA55                 ; write MBR special value

times 512 db 0            ; leave space for original BL copy, used in install.sh