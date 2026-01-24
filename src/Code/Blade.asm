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
	
// FUNCTION: init

InitMemoryManager:
	
	// this function will be run on computer startup
	// it accounts for the fact it will be loaded into memory before it is run

	// MEMORY FORMAT:
	// 0-36863: user program (36kb)
	// 36864-45055: kernel program (8kb)
	// 45056-49151: kernel heap (4kb)
	// 49152-55295: user heap (6kb)
	// 55296-65535: stack (10kb)

	// there is no bitmap to initialize
	// initialize the block header of the kernel heap
		// header format: free/used (1 bit) size (15 bits)
		// 0 means free and 1 means taken
	imm r1, 0b0001000000000000 // 4KiB
	store_16 [45056], r1
	// do the same for the user heap
	imm r1, 0b0001100000000000 // 6KiB
	store_16 [49152], r1
	// and the user program
	imm r1, 0b1000000000000000 // 32KiB
	store_16 [4096], r1
	
	// load memory manager functions into kernel program ram
	
	
	
	// FUNCTION: find heap block
	
		// navigate to the start of the heap
		imm r2, 36864
		// read the header of block 1 (2 bytes)
		load_16 r3, [r2]
		
		// if it's free (not negative)
		cmp r3, 0
		// mask the first bit to get the size regardless
		and r3, r3, 0b0111111111111111
		jge 36
			// if it's taken, add that number to the address
			add r2, r2, r3
			jmp 4
		
		// only accept it if it can fit the size requested
			// size is stored in r1
		cmp r3, r1
		// TODO: i think this should search the next block? so add before jumping
		jl 4	// THIS IS INDEX 36 DURING RUNTIME
		
		// claim the header
		add r1, r1, 0b1000000000000000
		store_16 [r2], r1
		// prep the header for the next block
		sub r1, r1, 0b1000000000000000
		add r2, r2, r1
		cmp r1, r3
		je 68
		// create the next block's header
		sub r3, r3, r1
		store_16 [r2], r3

		return // THIS IS INDEX 72 DURING RUNTIME
		

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
	store_16 [45056], r1
	// do the same for the user heap
	imm r1, 0b0001100000000000 // 6KiB
	store_16 [49152], r1
	// and the user program
	imm r1, 0b0111111111111111 // 32KiB (32767B) (yes, we're 1 short...)
	store_16 [4096], r1
	

	// FUNCTION: FindFileFromDirectory

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

	// using the address stored in r13, find the size of the string we're dealing with from the block header
	sub FFFD_Args, FFFD_Args, 2	// offset pointer to the block header
	load_16 FFFD_Size, [FFFD_Args]
	add FFFD_Args, FFFD_Args, 2	// navigate back into the content of the block
	and FFFD_Size, FFFD_Size, 0b0111111111111111 // mask the first bit, we only care about the size
	// this size is how long we need to keep going for, at most. ideally, we can stop before reaching this limit.
	// every time you load_16, subtract 2 from this size value. only read if it's above 1.

	// start at the root
	imm FFFD_FsAddress, 192 	//(first inode, aka root's)

	// if the input string's size is 0, do nothing
	cmp FFFD_Size, zr
	je justReturn

	// LOOP HERE - FOR EVERY DIRECTORY IN THE SEARCH PATH
	ForEveryDirectory:

		// we are at an inode currently. use it to navigate to the data block and look for the value we have in r1.
		// byte 7 is the first one to contain a block pointer
		add FFFD_FsAddress, FFFD_FsAddress, 7

		// LOOP HERE - FOR EVERY BLOCK IN THIS DIRECTORY
		ForEveryBlock:
			pload_16 FFFD_FromDisk, [FFFD_FsAddress]
			// FFFD_FromDisk now contains this inode's first/next block pointer
			// assuming this is a directory, search the block's data for our filename. it can only be 15B max so we can use Args.
			push FFFD_FsAddress	// remember this filesystem address for later. if this block is a dud, we'll need to come back to it
			mov FFFD_FromDisk, FFFD_FsAddress

			ForEveryEntry:
				imm FFFD_CheckedBytes, 0
				pload_8 FFFD_InodeNumber, [FFFD_FsAddress]	// the first byte is the inode number. save it for later
				add FFFD_FsAddress, FFFD_FsAddress, 1 

				// LOOP HERE - FOR EVERY CHARACTER IN THIS ENTRY
				ForEveryCharacter:

					// check the size to make sure we're not going over
					cmp FFFD_Size, zr
					jle MaxSizeReached
					cmp FFFD_CheckedBytes, 15
					jle MaxSizeReached

					load_8 FFFD_FromMemory, [FFFD_Args]	// read in the filename query
					sub FFFD_Size, FFFD_Size, 1
					pload_8 FFFD_FromDisk, [FFFD_FsAddress] // read in the filename in the entry
					add FFFD_FsAddress, FFFD_FsAddress, 1 // go to the next byte/character
					add FFFD_Args, FFFD_Args, 1

					cmp FFFD_FromDisk, FFFD_FromMemory

					// if they're equal
					je ForEveryCharacter
					// passing the line above at any point will exit the loop. this is a do while equivalent.

				jmp NotThisEntry
				
				MaxSizeReached:	// we hit either the end of the query or the end of the entry, and there was never a mismatch.
					// this doesn't mean this is a match though! if we search for M, MemMan.KER shouldn't count.
					// if it is truly a match, Size must be 0 AND
					cmp FFFD_Size, zr
					jne NotThisEntry
					// checkedBytes == 0
					cmp FFFD_CheckedBytes, zr
					je FileFound
					// OR the next byte in the query is null
					pload_8 FFFD_FromDisk, [FFFD_FsAddress]
					cmp FFFD_FromDisk, zr
					je FileFound
					jne NotThisEntry

				NotThisEntry:
					// there was a mismatch, and the file is not in this entry.

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
					pload_16 FFFD_FsAddress, [FFFD_FsAddress]
					add FFFD_FsAddress, FFFD_FsAddress, 2	// go to the next 2 bytes (next pointer)
					jmp ForEveryBlock


		FileFound:

		FileNotFound:
			imm FFFD_InodeNumber, 0
			return


	// if successful:
		// return a pointer to the inode. the inode number is on this line.
	// else:
		// go to the next line and try again
			// where is the next line? where are we?
		// if this was our 4th attempt, go to the next block instead
	justReturn:
		return
	
	
END_PGRM:
jmp END_PGRM