// stop counter
// disable interrupts
push r1	// 0-7
counter r1	// 8-11
push r1	// 12-19
push flags	// 20-27

jmp 0	// 28-31

// await IRET

pop flags
pop r1
jmp r1
pop r1