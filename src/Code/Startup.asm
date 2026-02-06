BOOT:
	call InitInterrupts
	call InitHeaps
	call InitScheduler
	
	BeginExecution:
		push zr
		imm flags, 4096
		push flags
		ienable
		iret

END_PGRM:
	// this is never intended to run, but will catch runaway programs.
	jmp END_PGRM




InitHeaps:
	const USER_PGRM_HEAD = 4096
    const USER_PGRM_TAIL = 36862

    const KERNEL_PGRM_HEAD = 36864
    const KERNEL_PGRM_TAIL = 45055

    const KERNEL_HEAP_HEAD = 45056
    const KERNEL_HEAP_TAIL = 49151

    const USER_HEAP_HEAD = 49152
    const USER_HEAP_TAIL = 55295
	

	// establish protected memory regions

	ret
	
InitInterrupts:
	const CLOCK_INTERRUPT = 3968
	const KB_INTERRUPT = 3968

	imm r1, OnClockInterrupt
	store_16 [CLOCK_INTERRUPT], r1
	imm r1, OnKeyboardInterrupt
	store_16 [KB_INTERRUPT], r1
	
	ret
	
InitScheduler:
	ret
	
// ===== INTERRUPTS =====
OnClockInterrupt:
	iret


OnKeyboardInterrupt:
	iret