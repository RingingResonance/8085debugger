# 8085debugger

A tool for debugging and reverse engineering 8085 based systems. Fits on a 2K ROM.

Can work on any 8080 or Z80 based systems if the serial IO is modified accordingly, or if a second ROM chip is used with the appropriate routines written (as described at the bottom of this readme), as those CPU's don't have the RIM or SIM instructions that the 8085 has.

On initial startup the program will attempt to send the string "in!" out the serial port at a default rate of 1200baud on a 4mhz 8085 after it has found a place in ram to work with.
If it can't find a place in ram to work with it will continue to loop looking for memory so that the circuit can be probed. Once it has found enough memory, and the user has given it a baud rate by entering at least one character,
it will show it's welcome text along with the memory space it has found: xxxx - xxxx

By default, this memory space is the upper and lower addresses that the base and stack are stored. On moving the base or stack and a restart the program will reflect these, however this will not limit the user from using the old memory addresses.

Once it is ready for user input you must send a capital letter such as 'A' in order for the auto baud to function properly. Failure to do so will result in it recording the incorrect baud rate.

This program should work on systems with as little as 64Bytes of ram.

Usage: Type help for a list of commands. 

'a' is addresses and 'd' is data

You can press 'q' while in hexwrite to exit back to prompt.

hexread aaaa aaaa	(Read from memory.)

hexwrite aaaa aaaa	(Write to memory.)

ioread aa		(Read from IO address.)

iowrite aa dd		(Write to IO address.)

jump aaaa		(Jump execution to address specified.)

mvstk aaaa		(Move stack to specified address and restart.)

mvbas aaaa		(Move base to specified address and restart.)

The base is where a few variables and the command input array are stored. It counts up in memory as you type a command so it can be used to fill the memory with text until it overwrites the stack which starts at the top of found memory space.

The stack, as stated before, starts at the top of the found memory space and counts down.

I made both the base and stack starting memory locations moveable so that the user can write data to that memory space safely without overwriting the base or the stack.

On startup, the program will check for 0x76 at location 0x0801 after it has done it's memory check. If found it will jump to location 0x0802 where additional code can be placed for further initialization or another bootloader.

In addtion to the second rom bootloader, the program also looks for 0x76 at locations 0x0805 and 0x0809 for external TX and RX routines to be used instead of the default software serial port in order to support other CPUs, and

systems which may have DMA interfear with critical serial port timing. On finding 0x76 at one or both of those locations, the routine will jump to 0x0806 for TX, or 0x080A for RX. Simply poping the registures off the stack and a return is all that should be neaded after the AUX code has been run.

The 8085's IRQs have also been broken out to the second ROM if needed. Enough room is left for a single jump instruction for all bootloader/initialization, RX/TX, and IRQ code along with their '0x76' identifiers.

TRAP at 0x080D

5.5  at 0x0810

6.5  at 0x0813

7.5  at 0x0816

