// keep a list of programs
	// fixed-size array allowing a maximum of 10 programs to be executed
	// it contains all registers and the pc
	// this results in each entry being 30B
// execute these programs in order
// every clock interrupt, pause the current program and move to the next