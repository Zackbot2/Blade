// store MemMan.KER at the first block in user heap
const USER_HEAP_START = 49152

const memoryPointer = r13
const ssdPointer = r1
const value = r2

call InitKernelProgram

imm memoryPointer, USER_HEAP_START
imm value, 0b1000000000001010
store_16 [memoryPointer], value

add memoryPointer, memoryPointer, 2
imm value, 77 // M
store_8 [memoryPointer], value
add memoryPointer, memoryPointer, 1
imm value, 101 // e
store_8 [memoryPointer], value
add memoryPointer, memoryPointer, 1
imm value, 109 // m
store_8 [memoryPointer], value
add memoryPointer, memoryPointer, 1
imm value, 77 // M
store_8 [memoryPointer], value
add memoryPointer, memoryPointer, 1
imm value, 97 // a
store_8 [memoryPointer], value
add memoryPointer, memoryPointer, 1
imm value, 110 // n
store_8 [memoryPointer], value
add memoryPointer, memoryPointer, 1
imm value, 46 // .
store_8 [memoryPointer], value
add memoryPointer, memoryPointer, 1
imm value, 75 // K
store_8 [memoryPointer], value
add memoryPointer, memoryPointer, 1
imm value, 69 // E
store_8 [memoryPointer], value
add memoryPointer, memoryPointer, 1
imm value, 82 // R
store_8 [memoryPointer], value
imm memoryPointer, USER_HEAP_START

call FindFileFromDirectory
jmp END_PGRM


InitKernelProgram:
// INITIALIZE HEADERS
	// header format: free/used (1 bit) size (15 bits)
	// 0 means free and 1 means taken
	imm r1, 0b0001000000000000 // 4KiB
	store_16 [45056], r1
	// do the same for the user heap
	imm r1, 0b0001100000000000 // 6KiB
	store_16 [49152], r1
	// and the user program
	imm r1, 0b0111111111111111 // 32KiB (32767B) (yes, we're 1 byte short...)
	store_16 [4096], r1
	return

	// FUNCTION: FindFileFromDirectory
FindFileFromDirectory:

	// START: this will be loaded to RAM address 36864
	// where do we assume the args are?
	// what if we take in the location of where the name is, not the actual data? i like that.
	const FFFD_Args = r13
	const FFFD_Size = r12
	const FFFD_FsAddress = r11
	const FFFD_MemAddress = r10
	const FFFD_CheckedBytes = r9

	const FFFD_FromMemory = r1
	const FFFD_FromDisk = r2
	const FFFD_InodeNumber = r3
    const FFFD_InodeGroupNumber = r4

	// using the address stored in r13, find the size of the string we're dealing with from the block header
	push FFFD_Args
	load_16 FFFD_Size, [FFFD_Args]
	add FFFD_Args, FFFD_Args, 2	// navigate back into the content of the block
	and FFFD_Size, FFFD_Size, 0b0111111111111111 // mask the first bit, we only care about the size
	// this size is how long we need to keep going for, at most. ideally, we can stop before reaching this limit.
	// every time you load_16, subtract 2 from this size value. only read if it's above 1.

	// start at the root
	imm FFFD_FsAddress, 192 	//(first inode, aka root's)

	// if the input string's size is 0, do nothing
	cmp FFFD_Size, zr
	je END_FFFD

	// LOOP HERE - FOR EVERY DIRECTORY IN THE SEARCH PATH
	ForEveryDirectory:

		// we are at byte 0 of a directory inode currently. use it to navigate to the data block and look for the value we have in r1.
		// byte 7 is the first one to contain a block pointer
		add FFFD_FsAddress, FFFD_FsAddress, 7

		// LOOP HERE - FOR EVERY BLOCK IN THIS DIRECTORY
		ForEveryBlock:
			pload_16 FFFD_FromDisk, [FFFD_FsAddress]
			// FFFD_FromDisk now contains this inode's first/next block pointer
			// assuming this is a directory, search the block's data for our filename. it can only be 15B max so we can use Args.
			push FFFD_FsAddress	// remember this filesystem address for later. if this block is a dud, we'll need to come back to it
			mov FFFD_FsAddress, FFFD_FromDisk

			ForEveryEntry:
				push FFFD_Args
				push FFFD_Size
				imm FFFD_CheckedBytes, 0
				pload_8 FFFD_InodeNumber, [FFFD_FsAddress]	// the first byte is the inode number. save it for later
				add FFFD_FsAddress, FFFD_FsAddress, 1 
				pload_8 FFFD_InodeGroupNumber, [FFFD_FsAddress]	// the second byte is the inode's group number. save it for later
				add FFFD_FsAddress, FFFD_FsAddress, 1 

				// LOOP HERE - FOR EVERY CHARACTER IN THIS ENTRY
				ForEveryCharacter:

					// check the size to make sure we're not going over
					cmp FFFD_Size, zr
					jle MaxSizeReached
					cmp FFFD_CheckedBytes, 14
					jg MaxSizeReached

					load_8 FFFD_FromMemory, [FFFD_Args]	// read in the filename query
					sub FFFD_Size, FFFD_Size, 1
					pload_8 FFFD_FromDisk, [FFFD_FsAddress] // read in the filename in the entry
					add FFFD_FsAddress, FFFD_FsAddress, 1 // go to the next byte/character
					add FFFD_Args, FFFD_Args, 1
					add FFFD_CheckedBytes, FFFD_CheckedBytes, 1

					cmp FFFD_FromDisk, FFFD_FromMemory

					// if they're equal
					je ForEveryCharacter
					// passing the line above at any point will exit the loop. this is a do while equivalent.

				jmp NotThisEntry
				
				MaxSizeReached:	// we hit either the end of the query or the end of the entry, and there was never a mismatch.
					// this doesn't mean this is a match though! if we search for M, MemMan.KER shouldn't count.
					// if it is truly a match, Size must be 0 AND
					cmp FFFD_CheckedBytes, zr
					je DidCheckEntireName
					
					add FFFD_FsAddress, FFFD_FsAddress, 1
					push r1
					pload_8 r1, [FFFD_FsAddress]
					cmp r1, 0
					pop r1
					jne FileNotFound

					DidCheckEntireName:
					// check if the query was completed
					cmp FFFD_Size, zr
					je FileFound

					// OR the next byte in the query is null
					pload_8 FFFD_FromDisk, [FFFD_FsAddress]
					cmp FFFD_FromDisk, zr
					je FileFound

					// ORRR the next byte in the query is a slash OR backslash (47 and 92 respectively)
					cmp FFFD_FromDisk, 47
					je NextDirectory
					cmp FFFD_FromDisk, 92
					je NextDirectory

					// alright youre fucked
					jmp NotThisEntry

				NotThisEntry:
					// there was a mismatch, and the file is not in this entry.

					pop FFFD_Size
					pop FFFD_Args

					// each block has 4 entries.
					// if we're at the 4th entry, this block is a dud. navigate back to it
					// using the superblock, find the block size. FFFD_FsAddress % BLOCK_SIZE should be < 48
					pload_8 FFFD_FromDisk, [3]
					mod FFFD_FromDisk, FFFD_FsAddress, FFFD_FromDisk
					cmp FFFD_FromDisk, 48
					jge NotThisBlock
					
					// this block is still good. navigate to the next entry
					push r1
					mod r1, FFFD_FsAddress, 16	// see how far in we are to the current entry
					push r2
					imm r2, 16
					sub r1, r2, r1
					pop r2
					add FFFD_FsAddress, FFFD_FsAddress, r1	// jump to the first byte of the next entry
					pop r1
					jmp ForEveryEntry


			NotThisBlock:
				pop FFFD_FsAddress	// bring back the address from earlier. 
				// this address contains the pointer of the block we just searched.
				add FFFD_FsAddress, FFFD_FsAddress, 2	// go to the next 2 bytes (next pointer)
				// do not continue if the next pointer is null
				pload_16 FFFD_FromDisk, [FFFD_FsAddress]
				cmp FFFD_FromDisk, zr
				je FileNotFound
				sub FFFD_FsAddress, FFFD_FsAddress, 2

				// find if this wasn't the last direct pointer
				pload_8 FFFD_InodeNumber, [4]	// FFFD_InodeNumber is usable here as it will be overwritten anyway when looping or exiting
				
				// if we're in the inode map
				// navigate to the superblock
				// use it to find the blocks per group [9], block size [3], inode size [4] and inodes per group [5]
				pload_8 FFFD_FromDisk, [9]	// blocks per group
				pload_8 FFFD_CheckedBytes, [3]	// block size
				pload_8 FFFD_FromMemory, [5]	// inodes per group
				
				// (INODE_SIZE * INODES_PER_GROUP) / BLOCK_SIZE = INODE_BLOCKS_PER_GROUP
				mul FFFD_InodeNumber, FFFD_InodeNumber, FFFD_FromMemory
				div FFFD_InodeNumber, FFFD_InodeNumber, FFFD_CheckedBytes
				// (FFFD_FsAddress / BLOCK_SIZE) % BLOCKS_PER_GROUP = BLOCKS_INTO_GROUP
				div FFFD_CheckedBytes, FFFD_FsAddress, FFFD_CheckedBytes
				mod FFFD_FromDisk, FFFD_CheckedBytes, FFFD_FromDisk
				// BLOCKS_INTO_GROUP < INODE_BLOCKS_PER_GROUP + 3 = IS IN INODE MAP
				cmp FFFD_FromDisk, FFFD_InodeNumber
				jge IsOutsideInodeMap

					// FFFD_FsAddress % INODE_SIZE < INODE_SIZE - 2 = IS LAST DIRECT
					push FFFD_FsAddress
					mod FFFD_FsAddress, FFFD_FsAddress, FFFD_InodeNumber
					sub FFFD_InodeNumber, FFFD_InodeNumber, 2
					cmp FFFD_FsAddress, FFFD_InodeNumber
					pop FFFD_FsAddress
					jl WasLastDirectPointer
					jmp WasNotLastDirectPointer

				// if we aren't in the inode map
				IsOutsideInodeMap:
					// FFFD_FsAddress % BLOCK_SIZE > BLOCK_SIZE - INODE_SIZE = IS LAST DIRECT
					pload_8 FFFD_FromDisk, [3]
					sub FFFD_InodeNumber, FFFD_FromDisk, FFFD_InodeNumber
					mod FFFD_FromDisk, FFFD_FsAddress, FFFD_FromDisk
					cmp FFFD_FsAddress, FFFD_InodeNumber
					jg WasLastDirectPointer

				// if this wasn't the last direct pointer
				WasNotLastDirectPointer:
					// search the next block
					add FFFD_FsAddress, FFFD_FsAddress, 2	// go to the next 2 bytes (next pointer)
					jmp ForEveryBlock

				// if this WAS the last direct pointer
				WasLastDirectPointer:
					// navigate to the pointer in this address to begin searching the rest of the pointers.
					add FFFD_FsAddress, FFFD_FsAddress, 2	// go to the next 2 bytes (next pointer)
					pload_16 FFFD_FsAddress, [FFFD_FsAddress]
					jmp ForEveryBlock

		NextDirectory:
			// this is reached when the found entry was correct and the next character is a slash. FFFD_FsAddress points to the slash.
			// read the next character
			add FFFD_FsAddress, FFFD_FsAddress, 2
			pload_8 FFFD_FromDisk, [FFFD_FsAddress]

			// is this character null?
			cmp FFFD_FromDisk, zr
			je FileNotFound

			// is this character a slash or backslash?
			cmp FFFD_FromDisk, 47
			je FileNotFound
			cmp FFFD_FromDisk, 92
			je FileNotFound

			// navigate to the found inode using the number earlier.
			// inodes start at block 3
			// navigate to the superblock to get the block size
			mov FFFD_FsAddress, FFFD_InodeGroupNumber
			// the formula for GROUP_START_POINTER is GROUP_NUMBER*BLOCKS_PER_GROUP*BLOCK_SIZE
			pload_8 FFFD_FromDisk, [9]  // blocks per group
			mul FFFD_FsAddress, FFFD_FsAddress, FFFD_FromDisk
			pload_8 FFFD_FromDisk, [3]
			mul FFFD_FsAddress, FFFD_FsAddress, FFFD_FromDisk
			// the pointer for an inode with a number is (GROUP_START_POINTER + BLOCK_SIZE*3 + INODE_SIZE*INODE_NUMBER)
			mul FFFD_FromDisk, FFFD_FromDisk, 3
			add FFFD_FsAddress, FFFD_FsAddress, FFFD_FromDisk
			pload_8 FFFD_FromDisk, [4]
			mul FFFD_FromDisk, FFFD_FromDisk, FFFD_InodeNumber
			add FFFD_FsAddress, FFFD_FsAddress, FFFD_FromDisk
			// we should now be at the right inode!

			// is this a directory? the first byte is the file type
			pload_8 FFFD_FromDisk, [FFFD_FsAddress]
			cmp FFFD_FromDisk, 0b10000000	// 0b10000000 is the 'Folder' file type
			je ForEveryDirectory
			jne FileNotFound


	FileNotFound:
		imm FFFD_InodeNumber, 0b1111111111111111
        imm FFFD_InodeGroupNumber, 0
		jmp END_FFFD
	
	FileFound:
		pop FFFD_Size
		pop FFFD_Args
        // navigate to the found inode using the number earlier.
        // inodes start at block 3
        // navigate to the superblock to get the block size
        mov FFFD_FsAddress, FFFD_InodeGroupNumber
        pload_8 FFFD_FromDisk, [9]  // blocks per group
        // the formula for GROUP_START_POINTER is GROUP_NUMBER*BLOCKS_PER_GROUP*BLOCK_SIZE
        mul FFFD_FsAddress, FFFD_FsAddress, FFFD_FromDisk
        pload_8 FFFD_FromDisk, [3]
        mul FFFD_FsAddress, FFFD_FsAddress, FFFD_FromDisk
        // the pointer for an inode with a number is (GROUP_START_POINTER + BLOCK_SIZE*3 + INODE_SIZE*INODE_NUMBER)
        mul FFFD_FromDisk, FFFD_FromDisk, 3
        add FFFD_FsAddress, FFFD_FsAddress, FFFD_FromDisk
        pload_8 FFFD_FromDisk, [4]
        mul FFFD_FromDisk, FFFD_FromDisk, FFFD_InodeNumber
        add FFFD_FsAddress, FFFD_FsAddress, FFFD_FromDisk
        // we should now be at the right inode!
        add FFFD_FsAddress, FFFD_FsAddress, 7
            
		// for now, just return the pointer to the first data block in r1
        pload_16 r1, [FFFD_FsAddress]

		jmp END_FFFD

	END_FFFD:
		pop FFFD_Args
		return
	
	
END_PGRM:
jmp END_PGRM