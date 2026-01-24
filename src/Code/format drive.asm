const MAGIC_NUMBER = 1 // filesystem type

const DISK_SIZE = 65535
const BLOCK_SIZE = 64 // in bytes
const BLOCK_COUNT = 1024
const INODE_SIZE = 16 // in bytes
const INODES_PER_GROUP = 8
const GROUP_SIZE = 64 // in blocks

// TOTAL BLOCKS: 1024

// each BLOCK GROUP contains:
// block 0: superblock/backup superblock
// block 1: group descriptors (pointers to inode table block, first data block, etc)
// block 2: block bitmap (8B), inode bitmap (8B), reserved/padding (16B)
// blocks 3-10: inode table (4 inodes per block, 8 blocks allocated)
// blocks 12-63: data blocks (free unallocated space)


// each SUPERBLOCK contains:
// 0: magic number AKA FS type (1B)
// 1-2: total blocks (2B)
// 3: block size in bytes (1B)
// 4: inode size in bytes (1B)
// 5: number of inodes per block group (1B)
// 6: block group count (1B)
// 7: first data block (1B)
	// starting data block in a group
// 8: flags/reserved


// each INODE contains:
// 0: file type (1B)
// 1-2: size in bytes (2B)
// 3-4: timestamp (2B)
// 5-6: link count (2B)
	// this directly counts how many data entries link to it
	// upon creation, this will be 2. the link from itself, and the link from its parent
// 7-14: block pointers (8B)
	// each pointer is 2B
	// pointer #4 is an indirect pointer
	// this allows an inode to reference up to 35 blocks
	

call FormatDrive

ProcessComplete:
jmp ProcessComplete

WipeDisk:
	imm r13, 0
	imm r12, DISK_SIZE
	sub r12, r12, 1
	WipeDisk_WipeNextBytes:
		pstore_16 [r13], zr
		add r13, r13, 2
		cmp r13, r12
		jne WipeDisk_WipeNextBytes
	return

FormatDrive:
	// zero the drive
	call WipeDisk
	
	// create primary superblock
	const groupNumber = r11
	const blockNumber = r10
	imm groupNumber, 0
	
	InitializeNextGroup:
	
		imm blockNumber, 0 // BLOCK 0
		push groupNumber
		call CreateSuperblock
		pop groupNumber
		
		// create group descriptors
		push groupNumber
		add blockNumber, blockNumber, 1 // BLOCK 1
		push blockNumber
		call CreateGroupDescriptors
		pop blockNumber
		pop groupNumber
	
		// initialize block bitmaps
		// initialize inode table
		push groupNumber
		add blockNumber, blockNumber, 1 // BLOCK 2
		push blockNumber
		call InitializeGroupBitmaps
		pop blockNumber
		pop groupNumber
		
		// loop condition
		add groupNumber, groupNumber, 1
		push r1
		imm r1, BLOCK_COUNT
		// get total number of groups
		div r1, r1, GROUP_SIZE
		// loop if groupNumber*groupSize*
		cmp groupNumber, r1
		pop r1
		jl InitializeNextGroup
	
	call CreateRootDirectory
	call CreateMemoryManager
	
	return

CreateSuperblock:
	const addressingByte = r13
	mul addressingByte, groupNumber, BLOCK_SIZE
	mul addressingByte, addressingByte, GROUP_SIZE
	// each SUPERBLOCK contains:
	// 0: magic number AKA FS type (1B)
	imm r1, MAGIC_NUMBER
	// 1-2: total blocks (2B)
	imm r2, BLOCK_COUNT
	// 3: block size in bytes (1B)
	imm r3, BLOCK_SIZE
	// 4: inode size in bytes (1B)
	imm r4, INODE_SIZE
	// 5: number of inodes per block group (1B)
	imm r5, INODES_PER_GROUP
	// 6: block group count (1B)
	div r6, r2, GROUP_SIZE
	// 7-8: first data block pointer (2B)
		// starting data block, system-wide
	imm r7, BLOCK_SIZE
	mul r7, r7, 11
	// 9: blocks per group
	imm r8, BLOCK_COUNT
	div r8, r8, GROUP_SIZE
	// 10: flags/reserved
	
	// write the data, officially creating the superblock
	pstore_8 [addressingByte], r1
	add addressingByte, addressingByte, 1
	pstore_16 [addressingByte], r2
	add addressingByte, addressingByte, 2
	pstore_8 [addressingByte], r3
	add addressingByte, addressingByte, 1
	pstore_8 [addressingByte], r4
	add addressingByte, addressingByte, 1
	pstore_8 [addressingByte], r5
	add addressingByte, addressingByte, 1
	pstore_8 [addressingByte], r6
	add addressingByte, addressingByte, 1
	pstore_16 [addressingByte], r7
	add addressingByte, addressingByte, 2
	pstore_8 [addressingByte], r8
	add addressingByte, addressingByte, 1
	pstore_8 [addressingByte], zr
	return


GetByteFromGroupAndBlock:
	// example: B1, G2
	mul addressingByte, blockNumber, BLOCK_SIZE
	// = 64 (offset within group)
	push groupNumber
	mul groupNumber, groupNumber, GROUP_SIZE
	// = 128
	mul groupNumber, groupNumber, BLOCK_SIZE
	// = 128*64 = 8192
	add addressingByte, addressingByte, groupNumber
	// pop groupNumber to keep it the same after the function is run
	pop groupNumber
	return


CreateGroupDescriptors:
	// make sure to push any registers we use
	push r1
	push blockNumber
	push addressingByte

	const pointer = r1
	imm blockNumber, 1
	call GetByteFromGroupAndBlock
	
	// group's block bitmap pointer (2B)
	push addressingByte
	add blockNumber, blockNumber, 1
	call GetByteFromGroupAndBlock
	mov pointer, addressingByte
	pop addressingByte
	pstore_16 [addressingByte], pointer
	
	// group's inode bitmap pointer (2B)
	add addressingByte, addressingByte, 2
	add pointer, pointer, 8
	pstore_16 [addressingByte], pointer
	
	// group's first inode table pointer (2B)
	add addressingByte, addressingByte, 2
	push addressingByte
	add blockNumber, blockNumber, 1
	call GetByteFromGroupAndBlock
	mov pointer, addressingByte
	pop addressingByte
	pstore_16 [addressingByte], pointer

	// group's first data block pointer	
	add addressingByte, addressingByte, 2
	push blockNumber
	push addressingByte
	imm blockNumber, 11
	call GetByteFromGroupAndBlock
	mov pointer, addressingByte
	pop addressingByte
	pstore_16 [addressingByte], pointer
	pop blockNumber
	
	// inodes free in group (1B)
	add addressingByte, addressingByte, 2
	imm r1, 0
	imm r2, BLOCK_SIZE
	div r2, r2, INODE_SIZE // this gets the number of inodes per table (4)
	mul r1, r2, INODES_PER_GROUP // multiply that by the number of inode tables (8) and store it in r1
	pstore_8 [addressingByte], r1

	// blocks free in group (1B)
	add addressingByte, addressingByte, 1
	imm r1, GROUP_SIZE
	sub r1, r1, 3
	sub r1, r1, INODES_PER_GROUP
	pstore_8 [addressingByte], r1

	pop addressingByte
	pop blockNumber
	pop r1
	return
	

// find a given group's descriptor and use it to find bitmap location
GetBlockBitmapPointer:
	push blockNumber
	imm blockNumber, 1
	call GetByteFromGroupAndBlock
	pload_16 addressingByte, [addressingByte]
	pop blockNumber
	return
	
GetInodeBitmapPointer:
	push blockNumber
	imm blockNumber, 1
	call GetByteFromGroupAndBlock
	add addressingByte, addressingByte, 2
	pload_16 addressingByte, [addressingByte]
	pop blockNumber
	return
	

InitializeGroupBitmaps:
	call GetBlockBitmapPointer
	push r1
	imm r1, 0b1111111111111111 // 1 indicates free
	lsr r1, r1, 3
	lsr r1, r1, INODES_PER_GROUP
	pstore_16 [addressingByte], r1
	add addressingByte, addressingByte, 2
	push r2
	imm r2, INODES_PER_GROUP
	cmp r2, 13
	imm r1, 0b1111111111111111
	jle InitializeInodeBitmap
		sub r2, r2, 13
		lsr r1, r1, r2

	InitializeInodeBitmap:
	pstore_16 [addressingByte], r1
	pop r2
	add addressingByte, addressingByte, 2
	imm r1, 0b1111111111111111
	pstore_16 [addressingByte], r1
	add addressingByte, addressingByte, 2
	pstore_16 [addressingByte], r1
	add addressingByte, addressingByte, 2
	
	call GetInodeBitmapPointer
	imm r1, 0b1111111111111111
	pstore_16 [addressingByte], r1
	add addressingByte, addressingByte, 2
	pstore_16 [addressingByte], r1
	add addressingByte, addressingByte, 2
	
	pop r1
	return


const fileType = r1
const fileSize = r2
const timestamp = r3
const linkCount = r4
const inodeNumber = r5
const exactAddress = r11
const blockNumber = r12
const inodeNumber = r13

// FILE TYPES:
const fileType_null = 0
// 00000001: kernel program
const fileType_KER = 1
// 00000010: program
const fileType_pgrm = 2
// 10000000: spritesheet
const fileType_folder = 0b10000000

CreateRootDirectory:
	// read in file properties
	imm fileType, fileType_folder
	// read time_0. it's 2B (16b)
	time_0 r2
	
	// find a new inode to allocate
	// find a new block to allocate
	imm blockNumber, 11
	// mark it as taken in the block bitmap
	push r1
	pload_8 r1, [128]
	lsr r1, r1, 1
	pstore_8 [128], r1
		
	// mark it as taken in the inode bitmap
	pload_8 r1, [136]
	lsr r1, r1, 1	// shift it right, inserting a 0 at the first position.
	pstore_8 [136], r1
	// create the inode
	pop r1	// pop the r1 value from earlier
	
	// each INODE contains:
	// 0: file type (1B)
	imm exactAddress, 192	// address 192 is the beginning of block 4 in group 0 (3*64)
	pstore_8 [exactAddress], fileType
	// 1-2: size in bytes (2B)
	imm fileSize, BLOCK_SIZE	// this is a directory, so it's given 1 block for now
	add exactAddress, exactAddress, 2
	pstore_16 [exactAddress], fileSize
	// 3-4: timestamp (2B)
	add exactAddress, exactAddress, 2
	time_0 timestamp
	pstore_16 [exactAddress], timestamp
	// 5-6: link count (2B)
		// this directly counts how many data entries link to it
		// upon creation, this will be 2. the link from itself, and the link from its parent
		// even though this is the root and it has no parent, it still needs to know that. its parent will be itself.
	add exactAddress, exactAddress, 2
	imm linkCount, 3 // this includes Memory Manager
	pstore_16 [exactAddress], linkCount
	// 7-14: block pointers (8B)
		// each pointer is 2B. it stores the exact address
		// pointer #4 (from 1) is an indirect pointer
		// this allows an inode to reference up to 35 blocks
	// -- pointers to self --
	imm exactAddress, 192	// (3*64), first inode in the table
	push blockNumber
	imm blockNumber, 704	// byte 704 is the exact address of the first data block of the first block group
	pstore_16 [exactAddress], blockNumber
	
	// -- memory manager pointer
	imm exactAddress, 208 // (3*64+16), the next inode in the table
	imm blockNumber, 768	// byte 768 is is the first byte of the next block
	pstore_16 [exactAddress], blockNumber
	
	pop blockNumber
	// create the inode pointer in the data block
	imm exactAddress, 704
	
	
	// ==== DIRECTORY DATA ====
	
	imm inodeNumber, 0
	pstore_8 [exactAddress], inodeNumber
	
	add exactAddress, exactAddress, 1
	imm r1, 46 // .
	pstore_8 [exactAddress], r1
	
	//add inodeNumber, inodeNumber, 1
	// do not add to the inodeNumber, as this is root and it references itself twice.
	imm exactAddress, 720 // the next entry in the data block
	pstore_8 [exactAddress], inodeNumber
	add exactAddress, exactAddress, 1
	imm r1, 46 // .
	pstore_8 [exactAddress], r1
	add exactAddress, exactAddress, 1
	imm r1, 46 // .
	pstore_8 [exactAddress], r1
	
	
	imm exactAddress, 736 // the next entry in the data block
	add inodeNumber, inodeNumber, 1
	// index the memory manager
		// it has yet to exist, but is hardcoded so we can add it now
	pstore_8 [exactAddress], inodeNumber
	add exactAddress, exactAddress, 1
	
	imm r1, 77 // M
	pstore_8 [exactAddress], r1
	add exactAddress, exactAddress, 1
	imm r1, 101 // e
	pstore_8 [exactAddress], r1
	add exactAddress, exactAddress, 1
	imm r1, 109 // m
	pstore_8 [exactAddress], r1
	add exactAddress, exactAddress, 1
	imm r1, 77 // M
	pstore_8 [exactAddress], r1
	add exactAddress, exactAddress, 1
	imm r1, 97 // a
	pstore_8 [exactAddress], r1
	add exactAddress, exactAddress, 1
	imm r1, 110 // n
	pstore_8 [exactAddress], r1
	add exactAddress, exactAddress, 1
	imm r1, 46 // .
	pstore_8 [exactAddress], r1
	add exactAddress, exactAddress, 1
	imm r1, 75 // K
	pstore_8 [exactAddress], r1
	add exactAddress, exactAddress, 1
	imm r1, 69 // E
	pstore_8 [exactAddress], r1
	add exactAddress, exactAddress, 1
	imm r1, 82 // R
	pstore_8 [exactAddress], r1
	add exactAddress, exactAddress, 1
	
	return
	

CreateMemoryManager:
	// it will be at root/MemMan.KER
	
	// STEP 1: create the file
	// this will be hardcoded as the file system doesn't fucking exist yet (spoiler!)
	
	// read in file properties
	// not necessary; hardcoded later
	
	// read time_0
	time_0 r2
	
	// find a new inode to allocate
	// not necessary; hardcoded later
	
	// find a new block to allocate
	// take block 13 here as 12 is taken by root
	imm blockNumber, 13
	// mark it as taken in the block bitmap
	push r1
	pload_8 r1, [129]
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
	add exactAddress, exactAddress, 14
	imm fileType, fileType_KER
	pstore_8 [exactAddress], fileType
	// 1-2: size in bytes (2B)
	imm fileSize, 33
	add exactAddress, exactAddress, 2
	imm fileSize, 0
	pstore_16 [exactAddress], fileSize
	// 3-4: timestamp (2B)
	add exactAddress, exactAddress, 2
	time_0 timestamp
	pstore_16 [exactAddress], timestamp
	// 5-6: link count (2B)
		// this directly counts how many data entries link to it
		// upon creation, this will be 1. the link from its parent
	add exactAddress, exactAddress, 2
	imm linkCount, 1
	pstore_16 [exactAddress], linkCount
	// 7-14: block pointers (8B)
		// each pointer is 2B. it stores the exact address
		// pointer #4 (from 1) is an indirect pointer
		// this allows an inode to reference up to 35 blocks
	add exactAddress, exactAddress, 2
	push blockNumber
	imm blockNumber, 832	// the 2nd data block of the first group (13*64)
	pstore_16 [exactAddress], blockNumber
	add exactAddress, exactAddress, 2
	add blockNumber, blockNumber, BLOCK_SIZE
	pstore_16 [exactAddress], blockNumber
	pop blockNumber

	// it has already been hardcoded as a child of root
	
	//STEP 2: navigate to the data block and start creating program data!
	imm exactAddress, 832	// the 2nd data block of the first group (13*64)
	
	// low key, i don't actually know what to put here yet.
	
	return