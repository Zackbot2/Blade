call CreateRootDirectory

END_PGRM:
	jmp END_PGRM
	
jmp END_PGRM

const fileType = r1 // store values to a register as pstore does not support immediates
const fileSize = r2
const timestamp = r3
const linkCount = r4

const exactAddress = r11
const blockNumber = r12
const inodeNumber = r13


// FILE TYPES:
const fileType_Null = 0
// 00000001: kernel program
const fileType_KER = 1
// 00000010: program
const fileType_PGRM = 2
// 10000000: spritesheet
const fileType_SpriteSheet = 0b10000000

imm fileType, fileType_KER


// flow of creating a new file (before MM initialized):

// read in file properties
// read time_0
// find a new inode to allocate
	// mark it as taken in the inode bitmap
// find a new block to allocate
	// mark it as taken in the block bitmap
// create the inode
// create the inode pointer in the block
// create title (30 bytes, 2 bytes of nullspace)


// currently, this is fully functional.
// the problem is just that there's no uniform way to write to it yet.

CreateRootDirectory:
	// read in file properties
	// read time_0
	time_0 r2
	// find a new inode to allocate
	
	// find a new block to allocate
	// we're creating the root directory, so this will be 12 every time
	imm blockNumber, 12
	// mark it as taken in the block bitmap
	push r1
	pload_8 r1, [129] // why is this 129???
	lsr r1, r1, 1
	pstore_8 [129], r1
		
	// mark it as taken in the inode bitmap
	pload_8 r1, [136]
	lsr r1, r1, 1
	pstore_8 [136], r1
	// create the inode
	pop r1
	
	// each INODE contains:
	// 0: file type (1B)
	imm exactAddress, 192
	pstore_8 [exactAddress], fileType
	// 1-2: size in bytes (2B)
	imm fileSize, 33
	add exactAddress, exactAddress, 2
	pstore_16 [exactAddress], fileSize
	// 3-4: timestamp (2B)
	add exactAddress, exactAddress, 2
	pstore_16 [exactAddress], timestamp
	// 5-6: link count (2B)
		// this directly counts how many data entries link to it
		// upon creation, this will be 2. the link from itself, and the link from its parent
	add exactAddress, exactAddress, 2
	pstore_16 [exactAddress], linkCount
	// 7-14: block pointers (8B)
		// each pointer is 2B. it stores the exact address
		// pointer #4 (from 1) is an indirect pointer
		// this allows an inode to reference up to 35 blocks
	add exactAddress, exactAddress, 2
	push blockNumber
	imm blockNumber, 768
	pstore_16 [exactAddress], blockNumber
	pop blockNumber
	// create the inode pointer in the data block
	imm exactAddress, 768
	pstore_8 [exactAddress], zr
	
	// create title (30 bytes, 2 bytes of nullspace)
	
	add exactAddress, exactAddress, 3
	imm r1, 114 // r
	pstore_8 [exactAddress], r1
	add exactAddress, exactAddress, 1
	imm r1, 111 // o
	pstore_8 [exactAddress], r1
	add exactAddress, exactAddress, 1
	pstore_8 [exactAddress], r1
	add exactAddress, exactAddress, 1
	imm r1, 116 // t
	pstore_8 [exactAddress], r1
	add exactAddress, exactAddress, 1
	pstore_8 [exactAddress], zr
	
	return



