# 8085debugger
A tool for debugging and reverse engineering 8085 based systems.

On initial startup the program will attempt to send the string "in!" out the serial port at a default rate of 1200baud on a 4mhz 8085 after it has found a place in ram to work with.
If it can't find a place in ram to work with it will continue to loop looking for memory.

Once it is ready for user input you must send a capital letter such as 'A' in order for the auto baud to function properly. Failure to do so will result in it recording the incorrect baud rate.

Usage: Type help for a list of commands. 

'a' is addresses and 'd' is data

You can press 'q' while in hexwrite to exit back to prompt.

hexread aaaa aaaa

hexwrite aaaa aaaa

ioread aa

iowrite aa dd

jump aaaa