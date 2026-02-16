const kernel = 0b1111111111111111 // at bottom, 128B
const stack = 0b1111111101111111 // 128 from bottom (grows negative)
// GAP OF 1111100000100000 (63520)
const heap = 0b0000100100000000 // 2304 from top (grows positive)
const static = 0b0000100000000000 // 2048 from top, 256B
const program = 0 // from top

// KERNEL:

// STATIC:
