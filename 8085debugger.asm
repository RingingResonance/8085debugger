;# 8085 based system debugging tool.
;# Jarrett Cigainero 2022

;########################
;########################
;########################
;########################
;# Command and Text Locations
textstart	EQU	0x0044
htext		EQU	textstart + 0x0000
help		EQU	textstart + 0x0043
hexread		EQU	textstart + 0x0049
hexwrite	EQU	textstart + 0x0052
jump		EQU	textstart + 0x005C
ioread		EQU	textstart + 0x0062
iowrite		EQU	textstart + 0x006A
mvstk   	EQU	textstart + 0x0073
mvbas   	EQU	textstart + 0x007A
BadSyn      EQU textstart + 0x0082
ImIn		EQU	textstart + 0x0091
ucmd		EQU	textstart + 0x00BF
newln		EQU	textstart + 0x00BC
inprmt      EQU textstart + 0x00B9
prmt		EQU	textstart + 0x00D2
bkspce		EQU	textstart + 0x00D7
hex         EQU textstart + 0x00DB

;########################
;# IO space
dlits		EQU	0xF0	;8 bit diag light output address.

;########################
;# Memory
romSt		EQU	0x0000	;ROM start address
romEnd		EQU	0x07FF	;ROM end address. 2K ROM chip; no need to test before that.
secROM      EQU romEnd + 0x01   ;Start location of next rom to try and boot from. Looks for a 0x76 here, and jumps to the address just after.
exTX        EQU romEnd + 0x05   ;External TX routine. Looks for a 0x76 here, and jumps to the address just after.
exRX        EQU romEnd + 0x09   ;External RX routine. Looks for a 0x76 here, and jumps to the address just after.
irqT        EQU romEnd + 0x0D   ;Trap IRQ vector
irq5        EQU romEnd + 0x10   ;RST5.5 IRQ vector
irq6        EQU romEnd + 0x13   ;RST6.5 IRQ vector
irq7        EQU romEnd + 0x16   ;RST7.5 IRQ vector
;# Dynamic Memory map. These get added to the 'found block' start address
autobd		EQU	0x0000  ;autobaud setting
mendL		EQU	0x0001	;Memory block end address lower byte
mendH		EQU	0x0002	;Memory block end address upper byte
rdL         EQU 0x0003  ;read lower byte
rdH         EQU 0x0004  ;read upper byte
dio         EQU 0x0005  ;data IO
dioadr      EQU 0x0006  ;data IO address
dioret      EQU 0x0007  ;data IO return address
wrhx1       EQU 0x0008
wrhx2       EQU 0x0009
cmdstrt		EQU	0x000A	;Command Storage start address.

;########################
;# Constants
baudf		EQU	0x47	;0x35 for 2400 at 6 mhz, 0x47 for 1200 at 4mhz, 0x6D for 1200 at 6.144mhz
bitpat		EQU	0xAA	;Bit pattern to test memory with.
memstrt		EQU	romEnd + 0x01	;Memory test start location. We are using a 2K ROM chip so start after.

;#########################################################################################################
; Start by testing memory for read/write capability without using the stack as we don't have a place for it yet.
org 0x0000
Azero:	mvi  a,0x0F	;Disable IRQs
 	sim
;## Try to write some stuff to memory. ##
	lxi h,memstrt	;start address
tst1:	mvi m,bitpat	;load bit pattern into memory pointed to by HL
	mov a,l		;move L to A
	cpi 0xFF	;compare it to 0xFF
	jnz tstn1	;if not zero then jump
	mov a,h		;move H to A
	cpi 0xFF	;compare it to 0xFF
	jnz tstn1	;if not zero then jump

;## Now try to read it back. ##
	lxi h,memstrt	;start address
tst2:	mov a,m		;move MEM to A
	cpi bitpat	;compare it to number
	jz  match	;If memory matchs then jump
	jmp irqskp

;# Built in IRQ vectors.
org	0x0024		;TRAP
	jmp  irqT
org	0x002C		;RST5.5
	jmp  irq5
org	0x0034		;RST6.5
	jmp  irq6
org	0x003C		;RST7.5
	jmp  irq7

org 0x0044		;Leave space for text.
	nop		;Mark it with a few 0x00's for easier editing in the hex editor.
	nop
	nop
	nop

org 0x0123
irqskp:	mov a,l		;move L to A
	cpi 0xFF	;compare it to 0xFF
	jnz tstn2	;if not zero then jump
	mov a,h		;move H to A
	cpi 0xFF	;compare it to 0xFF
	jnz tstn2	;if not zero then jump
	jmp Merr	;Jump to Merr if we haven't found any memory avalible.

;## We found a match in data, now try to find the next address that doesn't match.
match:	mov b,h		;Move our start address into BC
	mov c,l
tst3:	mov a,m		;move MEM to A
	cpi bitpat	;compare it to number
	jnz endmem	;If memory doesn't match then jump
	mov a,l		;move L to A
	cpi 0xFF	;compare it to 0xFF
	jnz tstn3	;if not zero then jump
	mov a,h		;move H to A
	cpi 0xFF	;compare it to 0xFF
	jnz tstn3	;if not zero then jump
;# If we have gotten to here then that means the found block of ram goes all the way to 0xFFFF.
	jmp endme2

tstn1:	inx h
	jmp tst1

tstn2:	inx h
	jmp tst2

tstn3:	inx h
	jmp tst3

endmem: dcx h		;Our end memory address is actually one address before the end of the found block. Decrease HL by one to fix that.
endme2:	mov d,h		;Move end address into DE
	mov e,l
;At this point our start and end address for memory should be in BC and DE.
;Now we need to check to see if it's more than just a few bytes of memory before we try to use it as it could be memory locations used for I/O or patchy bad memory.
;## Check memory size ##
	mov a,b
	cmp d
	jz  smltst	;If both B and D are the same then we need to test against C and E.
	jnc Merr	;If not zero and there is no carry then that mean DE is smaller than BC and that shouldn't happen.
	jc  newhm	;If there is a carry here than we have at least 256 bytes of meory to play with. Move in to new home!
smltst:	mov a,c
	cmp e
	jz  tstagn	;If both address are the same then we only found one byte and that's not enough. Go back and keep checking.
	jnc Merr	;If not zero and there is no carry then that mean DE is smaller than BC and that shouldn't happen.
;At this point we have found a memory block that is greater than one byte. Now check to see if it's greater than 64 bytes. (0x40)
	mov a,e
	sub c
	sui 0x40
	jc  newhm
	jz  newhm
	jnc tstagn	;If we don't have at least 64 bytes then jump to tstagn and continue searching.
	jmp Merr	;If status bits are all wrong (this shouldn't happen) go to Merr and start over.

tstagn: inx h
	jmp tst2

Merr:	jmp  Azero	;If we have a failure try again so that the CPU keeps running during the debug process.

;#########################################################################################################################
;## We have a home, now we should be able to use memory and stack operations but carefully as we may not have much ram. ##
newhm:	SPHL		;HL should be at the top of our memory space, load the stack pointer to that location.
;BC should be our beginning address at this point.

;Boot loader check. Look for second rom to boot from that starts with 0x00.
    push b          ;Push them all onto the stack.
    push d
    push h
    lxi  h,secROM   ;Looking at this memory location.
    mov  a,m        ;Move that to A for comparison.
    cpi  0x76       ;Look for 0x76 at address 0x0801 indicating that a boot rom is present. 0x76 has a low chance of just being there unless it was deliberately put there.
    jz   secROM + 0x01 ;jump to second rom if it was found.
    nop             ;pattern of nop's in case the creator of the boot rom wants to jump back this address is easy to find.
    nop
    pop  h          ;if no rom found, continue on as normal.
    pop  d
    pop  b
    nop             ;pattern of nop's in case the creator of the boot rom wants to jump back this address is easy to find.
    nop
    nop
;##################################################
;# Load serial port timing variable with defaults
	lxi  h,autobd	;Load address index to HL
	dad  b		;Add BC to HL to point to actual memory location.
	mvi  m,baudf	;Load default variable into that memory address.

;# Move our end address to a spot in ram.
	lxi  h,mendL	;Load address index to HL
	dad  b		;Add BC to HL
	mov  m,e	;Do the data transfer.
	lxi  h,mendH	;Load address index to HL
	dad  b		;Add BC to HL
	mov  m,d	;Do the data transfer.
	mov  d,b	;Move BC to DE. This is our new memory start address.
	mov  e,c	;As long as we keep the contents of one of these two safe, we will always know where to start and where our memory end address is as it's stored in the memory locations just before this.
;######################################################
;# Print some text with default serial port timing variables
;# to let the user know we are ready for serial input
;# so that we can calculate new timing variables.
;External serial port routine check.
    nop             ;nop pattern to make it easier to find and edit the hex.
    lxi  h,exRX     ;Looking at this memory location.
    mov  a,m        ;Move that to A for comparison.
    cpi  0x76       ;Look for 0x76 indicating that an external routine is present.
    jz   wlcm       ;If found, skip the auto baud detection.
    nop
;$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
    lxi  h,inprmt	;The word "in"
	call print	;Print it even though the timing might be way off and only garbage gets through.
    call gtime  ;Get timing of serial port from user.

;# Print welcome text.
wlcm: lxi  h,ImIn	;Point to 1337 HAX0R T3XT
	call print	;Print some 1337 HAX0R T3XT
;#### Print memory space ####
;Print the range of the block of ram we found.
	mov  a,b
	call printh	;Print the contents of B
	mov  a,c
	call printh	;Print the contents of C
	mvi  a,0x2D	;Move char '-' into A to be used by TX
	call tx
;Now for the end address we have to get that info back out of our memory location mentioned earlier.
	lxi  h,mendH	;Load address index to HL
	dad  b		;Add BC to HL
	mov  a,m	;Do the data transfer.
	call printh	;Print the Upper 8 bits
	lxi  h,mendL	;Load address index to HL
	dad  b		;Add BC to HL
	mov  a,m	;Do the data transfer.
	call printh	;Print the Lower 8 bits

;Load a RET instruction to this spot in ram for use later.
    lxi  h,dioret  ;Use address indexed by 'dioret'
    dad  d
    mvi  m,0xC9 ;Move 'RET' operand to space in memory.

;###################################################
;###################################################
;###################################################
;############## Command Interpreter ################
prompt:	lxi  h,prmt	;print command promt stuff "NL + RET + '#:' "
	call print
	lxi  h,cmdstrt
	dad  d          ;DE should still be our base address.
	mov  b,h        ;From now on, BC is used to compare to HL to see how much was typed if anything was typed.
    mov  c,l

;###################################################################
;This is our command/Text input subroutine.
;No protection from keeping someone from typing until
;the program overwrites the stack!
mn:	call rx		;Loops in this sub waiting for a key press
 	mov  m,a	;Move keypress to memory
 	cpi  0x08	;Check what keypress is in A
 	jz   bkspc	;Check for Backspace.
	cpi  0x0D
 	jz   enter	;Check for Enter.
	mov  a,m    ;Echo not what has been typed, but what has been stored in memory.
 	call tx		;Now send it.
 	inx  h		;Key entered, move to next memory location.
 	jmp  mn		;Loop again.

enter:	mov  a,l	;check to see if anything was typed. If not then go back to prompt.
 	cmp  c          ;This is crude as if the correct amount of data is entered it won't catch this.
	jz   prompt
	push h
	lxi  h,newln	;Print newline when enter/return is pressed.
	call print
	pop  h
	jmp  cmdint     ;Jump to command interpreter.

bkspc:	mov  a,l	;Get address (stored in HL) of command array
 	cmp  c		;If it matches with BC then we have backspaced all the way
	jnz  backs	;Backspaced all the way.
	mov  a,h	;Get address (stored in HL) of command array
 	cmp  b		;If it matches with BC then we have backspaced all the way
	jz   mn		;Backspaced all the way, don't backspace anymore.
backs: 	dcx  h		;Backspace. Clear text on screen and decrease command array pointer (HL)
	push h
	lxi  h,bkspce
	call print
	pop  h
 	jmp  mn


;#####################################
;######## Command Comparison #########
;## help text command
cmdint:	mov  h,b	;Put the HL reg back to start of prompt array.
	mov  l,c
	push b		;Push BC onto the stack.
	push d		;Push DE onto the stack.
	lxi d,help	;############## Location of text to compare to. ################
	call cmdcmp
	mov a,b
	pop d		;Pop DE off the stack.
	pop b		;Pop BC off the stack.
 	cpi 0x02	;If cmdcmp returned a 2 then it wasn't a match. Move on to the next command to test.
 	jnz phelp	;Print Help Text.

;## hexread command
	mov  h,b	;Put the HL reg back to start of prompt array.
	mov  l,c
	push b		;Push BC onto the stack.
	push d		;Push DE onto the stack.
	lxi d,hexread	;############## Location of text to compare to. ################
	call cmdcmp
	mov a,b
	pop d		;Pop DE off the stack.
	pop b		;Pop BC off the stack.
 	cpi 0x02	;If cmdcmp returned a 2 then it wasn't a match. Move on to the next command to test.
 	jnz hread	;Print memory specified by user.

;## hexrite command
	mov  h,b	;Put the HL reg back to start of prompt array.
	mov  l,c
	push b		;Push BC onto the stack.
	push d		;Push DE onto the stack.
	lxi d,hexwrite	;############## Location of text to compare to. ################
	call cmdcmp
	mov a,b
	pop d		;Pop DE off the stack.
	pop b		;Pop BC off the stack.
 	cpi 0x02	;If cmdcmp returned a 2 then it wasn't a match. Move on to the next command to test.
 	jnz hwrite	;Allow user to input data manually into memory.

;## ioread command
	mov  h,b	;Put the HL reg back to start of prompt array.
	mov  l,c
	push b		;Push BC onto the stack.
	push d		;Push DE onto the stack.
	lxi d,ioread	;############## Location of text to compare to. ################
	call cmdcmp
	mov a,b
	pop d		;Pop DE off the stack.
	pop b		;Pop BC off the stack.
 	cpi 0x02	;If cmdcmp returned a 2 then it wasn't a match. Move on to the next command to test.
 	jnz rdIO	;Print IO specified by user.

;## iowrite command
	mov  h,b	;Put the HL reg back to start of prompt array.
	mov  l,c
	push b		;Push BC onto the stack.
	push d		;Push DE onto the stack.
	lxi d,iowrite	;############## Location of text to compare to. ################
	call cmdcmp
	mov a,b
	pop d		;Pop DE off the stack.
	pop b		;Pop BC off the stack.
 	cpi 0x02	;If cmdcmp returned a 2 then it wasn't a match. Move on to the next command to test.
 	jnz wrIO	;Print IO specified by user.

;## jump command
	mov  h,b	;Put the HL reg back to start of prompt array.
	mov  l,c
	push b		;Push BC onto the stack.
	push d		;Push DE onto the stack.
	lxi d,jump	;############## Location of text to compare to. ################
	call cmdcmp
	mov a,b
	pop d		;Pop DE off the stack.
	pop b		;Pop BC off the stack.
 	cpi 0x02	;If cmdcmp returned a 2 then it wasn't a match. Move on to the next command to test.
 	jnz usrjmp	;Jump execution to user specified address.

;## mvstk Move Stack command
	mov  h,b	;Put the HL reg back to start of prompt array.
	mov  l,c
	push b		;Push BC onto the stack.
	push d		;Push DE onto the stack.
	lxi d,mvstk	;############## Location of text to compare to. ################
	call cmdcmp
	mov a,b
	pop d		;Pop DE off the stack.
	pop b		;Pop BC off the stack.
 	cpi 0x02	;If cmdcmp returned a 2 then it wasn't a match. Move on to the next command to test.
 	jnz mvstack

;## mvbas Move Base command
	mov  h,b	;Put the HL reg back to start of prompt array.
	mov  l,c
	push b		;Push BC onto the stack.
	push d		;Push DE onto the stack.
	lxi d,mvbas	;############## Location of text to compare to. ################
	call cmdcmp
	mov a,b
	pop d		;Pop DE off the stack.
	pop b		;Pop BC off the stack.
 	cpi 0x02	;If cmdcmp returned a 2 then it wasn't a match. Move on to the next command to test.
 	jnz mvbase

;Unknown Command
	lxi  h,ucmd	;Print "Unknown Command"
	call print
	jmp  prompt	;If no command is found then jump back to prompt.

;#########################
;#### Text Comparator ####
cmdcmp:	push h
	mov h,d		;move DE to HL
	mov l,e
	mov b,m		;move char from ROM to b
	pop h		;get HL back
;check to see if the char we read from rom is 0x0A (new line) If so then all other chars have matched so far and we return 0x04.
	mov a,b		;move b to a
	cpi 0x0A	;check for 0x0A
	jz  done	;if found, then we are done.
;otherwise keep checking until we get a different char
	mov a,m		;move char from RAM to a
	cmp b		;compare a and b
	jnz diff	;if they are different than go back.
	inx d		;increment HL and DE
	inx h
	jmp cmdcmp	;do the next char
diff: 	mvi b,0x02	;RETURN 2	no match
	ret
done:	mvi b,0x04	;RETURN 4	match found
	ret

;######################################################################
;What our commands do go here.

;####
;mvbas
mvbase: mov  h,b ;First index HL to beginning of command array after the command.
    mov  l,c
    lxi  b,0x0006   ;How many chars is the command?
    dad  b
    call glong  ;Get address data from args, returns them in BC
    push b
    ;now get the old end address since we aren't changing it.
    lxi  h,mendH	;Load address index to HL
	dad  d		;Add BC to HL
	mov  b,m	;Do the data transfer.
	lxi  h,mendL	;Load address index to HL
	dad  d		;Add BC to HL
	mov  c,m	;Do the data transfer.
    mov  h,b    ;Move DE to HL, this is where our old end address should be stored.
    mov  l,c
    mov  d,b    ;Also copy it to DE
    mov  e,c
    pop  b
    jmp  newhm  ;Restart main program.

;####
;mvstk
mvstack: mov  h,b ;First index HL to beginning of command array after the command.
    mov  l,c
    lxi  b,0x0006   ;How many chars is the command?
    dad  b
    call glong  ;Get address data from args, returns them in BC
    mov  h,b    ;Move BC to HL
    mov  l,c
    mov  b,d    ;Move DE to BC, this is where our beginning address should be stored.
    mov  c,e
    mov  d,h    ;Move HL to DE, this is where our end address should be stored.
    mov  e,l
    jmp  newhm  ;Restart main program.

;####
;jump
usrjmp: mov  h,b ;First index HL to beginning of command array after the command.
    mov  l,c
    lxi  b,0x0005   ;How many chars is the command?
    dad  b
    call glong  ;Get address data from args, returns them in HL
    mov  h,b    ;Move BC to HL
    mov  l,c
    pchl        ;Move HL to program counter. AKA: Indirect Jump
    nop         ;NOP buffer.
    nop

;#### "ioread"
;Read IO address specified by user
rdIO: push b
    push d
    lxi  h,dio  ;Use address indexed by 'dio'
    dad  d
    mvi  m,0xDB ;Move 'IN' operand to space in memory.
    mov  h,b    ;Index to end of command where args will be
    mov  l,c
    lxi  b,0x0007   ;End of command, beginning of args.
    dad  b
    call hget   ;Get the first two args. This will be the IO address to read.
    lxi  h,dioadr  ;Use address indexed by 'dioadr'
    dad  d
    mov  m,a ;Move 'A' to memory address.
;Now do some call trickery.
    lxi  h,dio  ;Use address indexed by 'dio'
    dad  d      ;Add HL to DE
    call iojmp  ;This should call an address that immediately exchanges the HL reg with the Program counter.
    call printh ;Now print what we just read.
    pop d
    pop b
    jmp  prompt

;####
;Write to IO address specified by user
wrIO: push b
    push d
    lxi  h,dio  ;Use address indexed by 'dio'
    dad  d
    mvi  m,0xD3 ;Move 'OUT' operand to space in memory.
    mov  h,b    ;Index to end of command where args will be
    mov  l,c
    lxi  b,0x0008   ;End of command, beginning of args.
    dad  b
    call hget   ;Get the first two args. This will be the IO address to write to.
    push h
    lxi  h,dioadr  ;Use address indexed by 'dioadr'
    dad  d
    mov  m,a ;Move 'A' to memory address.
    pop  h
;Load 'A' with next arg
    inx  h
    call hget   ;Get the second two args. This will be the data to write.
;Now do some call trickery.
    lxi  h,dio  ;Use address indexed by 'dio'
    dad  d      ;Add HL to DE
    call iojmp  ;This should call an address that immediately exchanges the HL reg with the Program counter.
    pop d
    pop b
    jmp  prompt

iojmp: pchl     ;Jump to what ever is pointed to by HL

;####
;Print Help Text
phelp:	lxi  h,htext
	call print
	jmp  prompt

;####
;Write to specified memory space.
hwrite: 	push b
	push h
	push d
;First index HL to beginning of command array after the command.
    mov  h,b
    mov  l,c
    lxi  b,0x0009
    dad  b
    call adget  ;Get address data from args, returns them in HL and variable rdL + rdH
    call ptHL   ;Print first address
	lxi  b,0x0101

wrnxt: push h
    lxi  h,wrhx1
    dad  d
    call rx     ;Wait for user input
    call tx     ;Read it back
    cpi  0x71   ;Check for the letter 'q' in case user wants to quit
    jz   usrqt
    mov  m,a
    inx  h
    call rx     ;Wait for user input
    call tx     ;Read it back
    cpi  0x71   ;Check for the letter 'q' in case user wants to quit
    jz   usrqt
    mov  m,a
    dcx  h
    call hget   ;Convert the two HEX chars to a number
    pop  h
	mov  m,a	;store A in memory.
	mvi  a,0x20	;Space between hex numbers
	call tx
;# Check for if we need an extra space
	mov  a,b
	cpi  0x10
	cz   nxtcol
	inr  b
;# Check for if we need a new line
	mov  a,c
	cpi  0x04
	cz   nxtln
;# Check for end of memory
    push h
	mov  a,h
	lxi  h,rdH
	dad  d
	cmp  m
	jnz  wnxtmem
    pop  h
    push h
	mov  a,l
	lxi  h,rdL
	dad  d
	cmp  m
	jnz  wnxtmem
usrqt: pop  h
	pop  d
	pop  h
	pop  b
	jmp  prompt

wnxtmem: pop h
	inx  h
	jmp  wrnxt

;####
;Read specified memory space.
hread:	push b
	push h
	push d
;First index HL to beginning of command array after the command.
    mov  h,b
    mov  l,c
    lxi  b,0x0008
    dad  b
    call adget  ;Get address data from args, returns them in HL and variable rdL + rdH
    call ptHL   ;Print first address
	lxi  b,0x0101

rdnxt:	mov  a,m	;move memory to A so printh can use it
	call printh
	mvi  a,0x20	;Space between hex numbers
	call tx
;# Check for if we need an extra space
	mov  a,b
	cpi  0x10
	cz   nxtcol
	inr  b
;# Check for if we need a new line
	mov  a,c
	cpi  0x04
	cz   nxtln
;# Check for end of memory
    push h
	mov  a,h
	lxi  h,rdH
	dad  d
	cmp  m
	jnz  nxtmem
    pop  h
    push h
	mov  a,l
	lxi  h,rdL
	dad  d
	cmp  m
	jnz  nxtmem
    pop  h
	pop  d
	pop  h
	pop  b
	jmp  prompt

nxtmem: pop h
	inx  h
	jmp  rdnxt

;Formatting system. B is number of bytes per column. C is number of columns.
;HL is address to be read from or written to.
nxtcol:	mvi  b,0x00
	inr  c
	mvi  a,0x20	;Double space between columns.
	call tx
	ret

nxtln:	lxi  b,0x0101
	push  h
	lxi  h,newln
	call print
	pop  h
	inx  h
	call ptHL   ;Print start address of new line.
	dcx  h
	ret

;######################################################################
;Hex data stuff.

;Print HL in hex (xxxxh: )
ptHL:  mov  a,h
    call printh
    mov  a,l
    call printh
    push h
    lxi  h,hex
	call print
	pop  h
	ret

;# Gets address range data from args and returns them in HL and rdL + rdH.
adget: call glong
	inx  h      ;Space between the two addresses
	call hget
	push h
	lxi  h,rdH
	dad  d      ;add HL to the offset stored in DE
	mov  m,a
	pop  h
	call hget
	lxi  h,rdL
	dad  d
	mov  m,a
	mov  h,b
	mov  l,c
	ret

glong: call hget   ;Get long data from command arg. returns it in BC
	mov  b,a
	call hget
	mov  c,a
	ret
;Gets what ever two chars are pointed to by HL, converts them to data, and
;returns it in A
hget:   push b
        mvi  a,0x00
        call geth
        rlc
        rlc
        rlc
        rlc
        mov  b,a
        inx  h
        call geth
        ora  b
        inx  h
        pop  b
        ret

geth:   mov  a,m
        cpi  0x30   ;Check if smaller than 0x30
        jc   derr
        mov  a,m
        cpi  0x3A   ;Check if smaller than or equal to 0x39
        jc   ndcd
        mov  a,m
        cpi  0x41   ;Check if smaller than 0x41
        jc   derr
        mov  a,m
        cpi  0x47   ;Check if smaller than or equal to 0x46
        jc   udcd
        mov  a,m
        cpi  0x61   ;Check if smaller than 0x61
        jc   derr
        mov  a,m
        cpi  0x67   ;Check if smaller than or equal to 0x66
        jc   ldcd
        jmp  derr
ndcd:   sui  0x30
        ret
udcd:   sui  0x37
        ret
ldcd:   sui  0x57
        ret

derr:   lxi  h,BadSyn
        call print
        mvi  a,0x00     ;Return with 0x00 in A
        ret

;prints what ever is in the A reg in HEX out the serial port
printh:	push b
	mov  b,a	;Make a copy of A into the D reg.
	ani  0xF0	;AND A and 0xF0
	rlc		;Move the 4 remaining bits to the right.
	rlc
	rlc
	rlc
	call parsv	;Convert it to text
	call tx		;send the text
	mov  a,b	;Move D to A
	ani  0x0F
	call parsv	;Pars the result and put in in C
	call tx
	pop  b
	ret

parsv:	adi  0x30	; Add 0x30
	mov  c,a	; Make a copy of A
	sui  0x3A	; Check to see if it is larger than 0-9
	jc  pnum	; If it's not then return
	mov  a,c	; But if it is then add 0x07 to get HEX letter A-F
	adi  0x07
	ret
pnum:	mov  a,c
	ret

;######################################################################
;# prints a string pointed to by HL that is terminated by a null char.
print:	mov a,m
	cpi 0x00
	rz
	mov a,m
	call tx
	inx h
 	jmp print

;#### Everything below this line is our BIOS ####
;# RX and TX is our input and output.

;# Port timing.
fulbit:	lxi  h,autobd	;10 Load address index to HL
	dad  d		;8 Add DE to HL
    push  d     ;4
	mov  e,m	;4 Do the data transfer
	mvi d,0x01  ;4
fbt: mov a,e ;4
	sub d       ;4
	mov e,a     ;4
 	jnz fbt     ;7/10
    pop d       ;10
	ret         ;10

hlfbit:	lxi  h,autobd	;Load address index to HL
	dad  d		;Add DE to HL
    push  d
	mov  a,m	;Do the data transfer
    rar
    ani 0x7F
    mov  e,a
	mvi d,0x01
hbt: mov a,e
 	sub d
 	mov e,a
	jnz hbt
    pop  d
 	ret

;# Receive data byte from 8085's built in serial port.
rx:	push b
	push d
	push h
;External serial port routine check.
    nop             ;nop pattern to make it easier to find and edit the hex.
    lxi  h,exRX     ;Looking at this memory location.
    mov  a,m        ;Move that to A for comparison.
    cpi  0x76       ;Look for 0x76 indicating that an external routine is present.
    jz   exRX + 0x01   ;jump to external routine if it was found.
    nop
;$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
rx2:	rim		;Loop until we get a start bit.
	ora a
	jm rx2
	call fulbit
	call hlfbit
	mvi c,0x09
rrx:	dcr c		;10
	jz rrxnd	;7/10	If we have enough bits then jump to rrxnd
	rim		;4	Get bit from serial port
	ral		;4	Move bit into carry
	mov a,b		;4	Move B data into A
	rar		;4	Move bit from carry to A
	mov b,a		;4	move A back to B
	call fulbit
	jmp rrx		; Loop until we count enough bits.

rrxnd:	mov a,b		;return with data byte in A
	pop h
	pop d
	pop b
 	ret

;# Send data byte from reg A out 8085's built in serial port.
tx:	push b
	push d
	push psw
	push h
	mov b,a
;External serial port routine check.
    nop             ;nop pattern to make it easier to find and edit the hex.
    lxi  h,exTX     ;Looking at this memory location.
    mov  a,m        ;Move that to A for comparison.
    cpi  0x76       ;Look for 0x76 indicating that an external routine is present.
    jz   exTX + 0x01   ;jump to external routine if it was found.
    nop
;$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
	mvi a,0xCF
 	sim
 	call fulbit
	nop		;4
 	nop		;4
 	mvi a,0x4F	;start
 	sim
	call fulbit
	mvi c,0x09

ttx:	dcr c		;10
	jz ttxnd	;7/10
 	mov a,b		;4
	rrc		;4
 	mov b,a
	push b		;4
	mvi c,0x4F
 	ora c		;4
	sim		;4
	pop b
	call fulbit
	jmp ttx

ttxnd:	mvi a,0xCF	;stop
	sim
	call fulbit
 	call fulbit
	pop h
	pop psw
	pop d
	pop b
	ret

;# Get timing of serial port from user input.
gtime:	push b
	push d
	push h
gtm:	rim		;Loop until we get a start bit.
	ora a
	jm gtm
	lxi  b,0x0000
	call tinydl   ;10
;# test first bit received, we might receive more than one bit so check a second bit to make sure.
gtm2: inr  b  ;10
    rim		;4 Loop until we get the next bit.
	ora a   ;4
	jp gtm2 ;7/10
    call tinydl
;# check second bit.
gtm3: inr  c
    rim		;Loop until we get the next bit.
	ora a
	jm gtm3


;# Now figure out which is smaller.
    mov a,c ;Determine which one is smaller. (C - B)
    cmp b
    jc  smlc     ;If C is smaller than jump
    mov a,b
    jmp tmend
smlc:   mov a,c
tmend:  lxi  h,autobd	;Load address index to HL
	dad  d		;Add DE to HL
    mov  m,a
	pop h
	pop d
	pop b
 	ret

;needs to be about 140 cycles
tinydl: push d
    mvi d,0x05
tdl: dcr d      ;10
    jnz  tdl    ;7/10
    pop d
    ret     ;10

	hlt
