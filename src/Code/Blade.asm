// MEMORY FORMAT:
// 0-36863: user program (36kb)
// 36864-45055: kernel program (8kb)
// 45056-49151: kernel heap (4kb)
// 49152-55295: user heap (6kb)
// 55296-65535: stack (10kb)


const STACK_OFFSET = 0 // what's a stack offset?

const pixelColour = r1
const pixelPosition = r2
const characterValue = r3
const accessValue = r12
const accessAddress = r13

const maxPixelPosition = 19200



// set stack offset
imm sp, STACK_OFFSET

//jmp PrintAllCharacters

call Startup

jmp END_PGRM

// FUNCTIONS:
Startup:
	call BootMemoryManager
	
	
	call DisplayStartup
	
	imm pixelColour, white
	imm characterValue, 72
	imm pixelPosition, 161
	push pixelPosition
	call DrawCharacter
	
	pop pixelPosition
	add pixelPosition, pixelPosition, 9
	push pixelPosition
	imm characterValue, 101
	call DrawCharacter
	
	pop pixelPosition
	add pixelPosition, pixelPosition, 9
	push pixelPosition
	imm characterValue, 108
	call DrawCharacter
	
	pop pixelPosition
	add pixelPosition, pixelPosition, 9
	push pixelPosition
	imm characterValue, 108
	call DrawCharacter
	
	pop pixelPosition
	add pixelPosition, pixelPosition, 9
	push pixelPosition
	imm characterValue, 111
	call DrawCharacter
	
	pop pixelPosition
	add pixelPosition, pixelPosition, 9
	push pixelPosition
	imm characterValue, 32
	call DrawCharacter
	
	pop pixelPosition
	add pixelPosition, pixelPosition, 9
	push pixelPosition
	imm characterValue, 119
	call DrawCharacter
	
	pop pixelPosition
	add pixelPosition, pixelPosition, 9
	push pixelPosition
	imm characterValue, 111
	call DrawCharacter
	
	pop pixelPosition
	add pixelPosition, pixelPosition, 9
	push pixelPosition
	imm characterValue, 114
	call DrawCharacter
	
	pop pixelPosition
	add pixelPosition, pixelPosition, 9
	push pixelPosition
	imm characterValue, 108
	call DrawCharacter
	
	pop pixelPosition
	add pixelPosition, pixelPosition, 9
	push pixelPosition
	imm characterValue, 100
	call DrawCharacter
	
	pop pixelPosition
	add pixelPosition, pixelPosition, 9
	push pixelPosition
	imm characterValue, 33
	call DrawCharacter
	pop pixelPosition
	
	return
	
BootMemoryManager:
	return


DisplayStartup:
	imm pixelColour, navy
	call DrawBackground
	return


DrawBackground:
	imm pixelPosition, 0
	
	DrawBackground_Draw:	
		draw pixelColour, [pixelPosition]
		add pixelPosition, pixelPosition, 1
		cmp pixelPosition, maxPixelPosition
		jle DrawBackground_Draw
	
	imm pixelPosition, 0
	return

	
DrawCharacter:
	const characterOffset = r4
	const iterations = r3
	// load SSD access address and calibrate for character value
	push characterValue
	mul characterValue, characterValue, 8
	//imm accessAddress, defaultCharacterAddress
	sub accessAddress, accessAddress, characterValue
	imm iterations, 0
	
	// load first byte of character to memory
	DrawCharacter_LoadByte:
	
		// if the end has been reached
		// if iterations == 8
		cmp iterations, 8
		jl DrawCharacter_DrawByte
			pop characterValue
			return
		
		DrawCharacter_DrawByte:
			pload_8 accessValue, [accessAddress]
			imm characterOffset, 0
			
			// shift left 8
			lsl accessValue, accessValue, 8
			
			DrawCharacter_DrawNextBit:
			// if negative
			cmp accessValue, 0
			jge DrawCharacter_CheckPixelOffset
				// place pixel here
				draw pixelColour, [pixelPosition]
			
			
			DrawCharacter_CheckPixelOffset:
			// if offset >=8:
			cmp characterOffset, 8
			jl DrawCharacter_NotLastBit
				// add 160 to pixel position
				add pixelPosition, pixelPosition, 152
				// load next byte
				sub accessAddress, accessAddress, 1
				add iterations, iterations, 1
				jmp DrawCharacter_LoadByte
				
				
			DrawCharacter_NotLastBit:
			// else:
				// add 1 to pixel position
				add pixelPosition, pixelPosition, 1
				add characterOffset, characterOffset, 1	
				// shift left by 1
				lsl accessValue, accessValue, 1
				jmp DrawCharacter_DrawNextBit
		
	
Shutdown:
	imm pixelColour, gray
	call DrawBackground
	return
	
PrintAllCharacters:
	imm pixelColour, white
	imm characterValue, 0
	imm pixelPosition, 164
	PrintAllCharacters_PrintNext:
		cmp characterValue, 255
		jg END_PGRM
		push pixelPosition
		
		mod pixelPosition, pixelPosition, 160
		cmp pixelPosition, 145
		jl PrintAllCharacters_PrintNext_PRINT_IT
			pop pixelPosition
			add pixelPosition, pixelPosition, 1296
			push pixelPosition
			jmp PrintAllCharacters_PrintNext_PRINT_IT1
			
		PrintAllCharacters_PrintNext_PRINT_IT:
		pop pixelPosition
		push pixelPosition
		PrintAllCharacters_PrintNext_PRINT_IT1:
		call DrawCharacter
		pop pixelPosition
		add characterValue, characterValue, 1
		add pixelPosition, pixelPosition, 9
		jmp PrintAllCharacters_PrintNext
	
// initialize the kernel program
InitKernelProgram:
	// the purpose of this code is to load core FS and MM functionality
	// to kickstart the rest of the system.
	
	// by the time this finishes running, the system should know how to:
		// - find the contents of a file by directory
		// - read from a file and allocate it to the user program
		// - run programs in UPG and KPG memory using UH and KH respectively
	
	// ============================================================================

	// INITIALIZE HEADERS
	// header format: free/used (1 bit) size (15 bits)
	// 0 means free and 1 means taken
	imm r1, 0b0001000000000000 // 4KiB
	sub r1, r1, 2
	store_16 [45056], r1
	// do the same for the user heap
	imm r1, 0b0001100000000000 // 6KiB
	sub r1, r1, 2
	store_16 [49152], r1
	// and the user program
	imm r1, 0b0111111111111111 // 32KiB (32767B)
	sub r1, r1, 1
	store_16 [4096], r1
	

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
				pload_16 FFFD_InodeNumber, [FFFD_FsAddress]	// the first byte is the inode number. save it for later
				add FFFD_FsAddress, FFFD_FsAddress, 2

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


			const blockSize = r1
			const groupSize = r2
			const blocksPerGroup = r5
			const groupNumber = r4
			const inodesPerGroup = r7
			const inodeSize = r8

			push r1
			push r2
			push r4
			push r5
			push r7
			push r8

			// navigate to the found inode using the number earlier.
			// inodes start at block 3
			// navigate to the superblock to get the block size
			pload_8 blockSize, [3]
			pload_8 inodeSize, [4]
			pload_8 inodesPerGroup, [5]
			pload_8 blocksPerGroup, [9]
			mul groupSize, blockSize, blocksPerGroup

			// FFFD_FsAddress = floor(FFFD_InodeNumber/inodesPerGroup)*groupSize + 3*blockSize + inodeSize * FFFD_InodeNumber
			div FFFD_FsAddress, FFFD_InodeNumber, inodesPerGroup
			mul FFFD_FsAddress, FFFD_FsAddress, groupSize

			mul blockSize, blockSize, 3
			add FFFD_FsAddress, FFFD_FsAddress, blockSize

			mul inodeSize, inodeSize, FFFD_InodeNumber
			add FFFD_FsAddress, FFFD_FsAddress, inodeSize
			// we should now have the pointer to the right inode!

			// is this a directory? the first byte is the file type
			pload_8 FFFD_FromDisk, [FFFD_FsAddress]
			cmp FFFD_FromDisk, 0b10000000	// 0b10000000 is the 'Folder' file type
			pop r1
			pop r2
			pop r4
			pop r5
			pop r7
			pop r8
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
        
		const blockSize = r1
        const groupSize = r2
		const blocksPerGroup = r5
		const groupNumber = r4
		const inodesPerGroup = r7
		const inodeSize = r8


		pload_8 blockSize, [3]
		pload_8 inodeSize, [4]
		pload_8 inodesPerGroup, [5]
		pload_8 blocksPerGroup, [9]
		mul groupSize, blockSize, blocksPerGroup

		// FFFD_FsAddress = floor(FFFD_InodeNumber/inodesPerGroup)*groupSize + 3*blockSize + inodeSize * FFFD_InodeNumber
		div FFFD_FsAddress, FFFD_InodeNumber, inodesPerGroup
		mul FFFD_FsAddress, FFFD_FsAddress, groupSize

		mul blockSize, blockSize, 3
		add FFFD_FsAddress, FFFD_FsAddress, blockSize

		mul inodeSize, inodeSize, FFFD_InodeNumber
		add FFFD_FsAddress, FFFD_FsAddress, inodeSize
        // we should now have the pointer to the right inode!

		// for now, just return the pointer to the inode in r1
        mov r1, FFFD_FsAddress
		jmp END_FFFD

	END_FFFD:
		pop FFFD_Args
		return
	
	
END_PGRM:
jmp END_PGRM