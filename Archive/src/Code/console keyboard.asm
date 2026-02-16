call jump_to_end
read_key:
keyboard r1
cmp r1, 0
jge read_key
lsl r2, r1, 8
lsr r2, r2, 8
cmp r2, 4
je doBackspace
call check_disallowed
pstore_8 [r3], r1
add r3, r3, 1
jmp read_key

doBackspace:
	backspace
	jmp read_key
	
jump_to_end:
	imm r3, 0b1111111111111111	
	start:
	add r3, r3, 1
	pload_8 r1, [r3]
	cmp r1, 0
	jne start
	ret
	
check_disallowed:
	cmp r2, 30
	jl skip_character
	ret
	skip_character:
	add sp, sp, 2
	jmp read_key