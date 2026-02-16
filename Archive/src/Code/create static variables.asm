const kernel = 0b1111111111111111 // at bottom
const freeSpace = 0 // from top

// KERNEL:


// CHARACTERS

// each byte represents 8 pixels
// each character is 8B aka an 8x8 grid of 0-1
jmp start
done:
jmp done

start:
const defaultCharacterAddress = 0b1111111111101111
imm r2, defaultCharacterAddress
imm r3, 48
mul r3, r3, 8
sub r2, r2, r3

imm r1, 0b00111100
pstore_8 [r2], r1

imm r1, 0b01000110
sub r2, r2, 1
pstore_8 [r2], r1

imm r1, 0b01001010
sub r2, r2, 1
pstore_8 [r2], r1

imm r1, 0b01001010
sub r2, r2, 1
pstore_8 [r2], r1

imm r1, 0b01010010
sub r2, r2, 1
pstore_8 [r2], r1

imm r1, 0b01010010
sub r2, r2, 1
pstore_8 [r2], r1

imm r1, 0b01100010
sub r2, r2, 1
pstore_8 [r2], r1

imm r1, 0b00111100
sub r2, r2, 1
pstore_8 [r2], r1

jmp done