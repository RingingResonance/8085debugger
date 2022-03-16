# 8085debugger
A tool for debugging and reverse engineering 8085 based systems.
Can work on any 8080 or Z80 based systems if the serial IO is modified accordingly as those CPU's don't have the RIM or SIM instructions that the 8085 has.

On initial startup the program will attempt to send the string "in!" out the serial port at a default rate of 1200baud on a 4mhz 8085 after it has found a place in ram to work with.
If it can't find a place in ram to work with it will continue to loop looking for memory so that the circuit can be probed.

Once it is ready for user input you must send a capital letter such as 'A' in order for the auto baud to function properly. Failure to do so will result in it recording the incorrect baud rate.

Usage: Type help for a list of commands. 

'a' is addresses and 'd' is data

You can press 'q' while in hexwrite to exit back to prompt.

hexread aaaa aaaa	(Read from memory.)

hexwrite aaaa aaaa	(Write to memory.)

ioread aa		(Read from IO address.)

iowrite aa dd		(Write to IO address.)

jump aaaa		(Jump execution to address specified.)

mvstk aaaa		(Move stack to specified address and restart.)

mvbas aaaa		(Move base addres to specified address and restart.)
