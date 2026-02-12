imm r1, 69
cstore ksp, r1
imm r1, END
cstore limit, r1
imm r1, User
cstore base, r1
cstore cause, r1
imm r1, OnClockInterrupt
store_16 [3968], r1
imm r1, 0x8000
store_16 [4032], r1
ienable
trap
nop
nop
nop

launch_user User
exret

User:
	nop
	nop
	nop
	nop
	nop
	nop
	jmp User
END:
	jmp END
	
OnClockInterrupt:
	exret