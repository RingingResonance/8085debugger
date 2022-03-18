# 8085debugger

A tool for debugging and reverse engineering 8085 based systems. Fits on a 2K ROM.

Can work on any 8080 or Z80 based systems if the serial IO is modified accordingly as those CPU's don't have the RIM or SIM instructions that the 8085 has.

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
