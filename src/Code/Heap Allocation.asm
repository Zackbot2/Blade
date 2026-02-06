
const USER_HEAP_START = 49152

const memoryPointer = r13
const ssdPointer = r1
const value = r2

imm r1, OnClockInterrupt
store_16 [3968], r1

imm r1, OnIretAVF
store_16 [4088], r1

call InitKernelProgram

push flags
imm flags, Start
push flags
iret



Start:
iret
imm memoryPointer, USER_HEAP_START
imm value, 0b1000000000001010
store_16 [memoryPointer], value

// write memory manager name to memory
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
    imm value, 107 // K
    store_8 [memoryPointer], value
    add memoryPointer, memoryPointer, 1
    imm value, 101 // E
    store_8 [memoryPointer], value
    add memoryPointer, memoryPointer, 1
    imm value, 114 // R
    store_8 [memoryPointer], value
    imm memoryPointer, USER_HEAP_START

call FindFileFromDirectory
mov r13, r1
imm r12, 0b1000000000000001

call AllocateFileToMemory


jmp END_PGRM

// ============================================================================================================

AllocateFileToMemory:

    const USER_PGRM_HEAD = 4096
    const USER_PGRM_TAIL = 36862

    const KERNEL_PGRM_HEAD = 36864
    const KERNEL_PGRM_TAIL = 45055

    const KERNEL_HEAP_HEAD = 45056
    const KERNEL_HEAP_TAIL = 49151

    const USER_HEAP_HEAD = 49152
    const USER_HEAP_TAIL = 55295

    // expect FS pointer in r13, heap protocol in r12

    // depending on the heap protocol, load the corresponding head and tail
    // negative = kernel
    // odd = pgrm
    // 16 bit format

    const r2_heapHead = r2
    const r3_heapTail = r3

    const r1_returnValue = r1
    const r13_fsPointer = r13
    const r12_heapProtocol = r12

    DefineHeap:

        KernelMode:
            KernelHeap:
                imm r2_heapHead, KERNEL_HEAP_HEAD
                imm r3_heapTail, KERNEL_HEAP_TAIL
                jmp ReadFileSize

            KernelProgram:
                imm r2_heapHead, KERNEL_PGRM_HEAD
                imm r3_heapTail, KERNEL_PGRM_TAIL
                jmp ReadFileSize


        UserMode:
            UserHeap:
                imm r2_heapHead, USER_HEAP_HEAD
                imm r3_heapTail, USER_HEAP_TAIL
                jmp ReadFileSize

            UserProgram:
                imm r2_heapHead, USER_PGRM_HEAD
                imm r3_heapTail, USER_PGRM_TAIL
                jmp ReadFileSize


    const r2_memPointer = r2
    const r11_fileSize = r11
    const r10_sizeAllocated = r10
    const r10_blockSize = r10

    ReadFileSize:
        // read the size of the file we wish to allocate
        add r13_fsPointer, r13_fsPointer, 1
        
        pload_16 r11_fileSize, [r13_fsPointer]
        cmp r11_fileSize, 0
        je AllocationFail  // don't even bother for files with no size
        
        // memory pointer has already been designated the same register as the heap head.
        // this means there is no need to navigate to it since we're already there.

    CheckBlock:
        // this point in the program assumes the current memory pointer points to the head of a block.

        load_16 r10_blockSize, [r2_memPointer]
        // these 2 bytes contain both the free status and the size
        // if it's negative, that means it's used.
        cmp r10_blockSize, 0

        // get the real size of the block by masking the first bit
        and r10_blockSize, r10_blockSize, 0b0111111111111111
        jl GoToNextBlock

        // check block size
        cmp r10_blockSize, r11_fileSize
        jge ClaimBlock

        GoToNextBlock:
            add r2_memPointer, r2_memPointer, r10_blockSize
            cmp r2_memPointer, r3_heapTail
            jmp CheckBlock
            return  // return if we reached the end of the heap without finding anywhere free.
    
	ClaimBlock:
    push r11_fileSize
    or r11_fileSize, r11_fileSize, 0b1000000000000000   // not sure what the term is for this, but set only the first bit to 1. it's like the opposite of masking..?
    store_16 [r2_memPointer], r11_fileSize
    pop r11_fileSize

    // create the next block
    push r2_memPointer
    add r2_memPointer, r2_memPointer, r11_fileSize
    add r2_memPointer, r2_memPointer, 2 // add 2 because we *were* at the head, which is 2 bytes. the size only accounts for the data portion.
    cmp r2_memPointer, r3_heapTail
    jge NavigateBack

    sub r10_blockSize, r10_blockSize, r11_fileSize
    sub r10_blockSize, r10_blockSize, 2

    store_16 [r2_memPointer], r10_blockSize

    NavigateBack:
    pop r2_memPointer
    mov r1_returnValue, r2_memPointer


    // =============================== BEGIN COPYING DATA ===============================
    const r4_inodePointer = r4
    const r5_tempStore = r5
    add r13_fsPointer, r13_fsPointer, 6 // move from the inode size to the block pointers
    add r2_memPointer, r2_memPointer, 2 // move from the block head to the block contents
    imm r10_sizeAllocated, 0

    CopyFromDataBlock:

        mov r4_inodePointer, r13_fsPointer  // remember this fsPointer so we can return to it later.
        pload_16 r13_fsPointer, [r13_fsPointer]

        CopyByte:

            pload_8 r5_tempStore, [r13_fsPointer]
            store_8 [r2_memPointer], r5_tempStore
            add r2_memPointer, r2_memPointer, 1
            add r13_fsPointer, r13_fsPointer, 1
            add r10_sizeAllocated, r10_sizeAllocated, 1

            cmp r10_sizeAllocated, r11_fileSize

            jge AllocationSuccess

            // determine if we're at the end of the block (BLOCK_SIZE % 64 == 0)
            push r1
            pload_8 r1, [3]
            mod r1, r13_fsPointer, r1
            cmp r1, 0
            pop r1
            jne CopyByte


        NavigateToNextBlock:

            const r9_blocksPerGroup = r9
            const r6_blockSize = r6
            const r7_inodesPerGroup = r7
            const r8_inodeSize = r8

            mov r13_fsPointer, r4_inodePointer	// bring back the address from earlier. 
            // this address contains the pointer of the block we just searched.
            add r13_fsPointer, r13_fsPointer, 2	// go to the next 2 bytes (next pointer)
            // do not continue if the next pointer is null
            pload_16 r5_tempStore, [r13_fsPointer]
            cmp r5_tempStore, zr
            je AllocationFail
            sub r13_fsPointer, r13_fsPointer, 2

            // find if this wasn't the last direct pointer
            pload_8 r8_inodeSize, [4]
            
            // if we're in the inode map
            // navigate to the superblock
            // use it to find the blocks per group [9], block size [3], inode size [4] and inodes per group [5]
            pload_8 r9_blocksPerGroup, [9]	// blocks per group
            pload_8 r6_blockSize, [3]	// block size
            pload_8 r7_inodesPerGroup, [5]	// inodes per group
            
            // (INODE_SIZE * INODES_PER_GROUP) / BLOCK_SIZE = INODE_BLOCKS_PER_GROUP
            mul r8_inodeSize, r8_inodeSize, r7_inodesPerGroup
            div r8_inodeSize, r8_inodeSize, r6_blockSize
            // (r13_fsPointer / BLOCK_SIZE) % BLOCKS_PER_GROUP = BLOCKS_INTO_GROUP
            div r5_tempStore, r13_fsPointer, r6_blockSize
            mod r9_blocksPerGroup, r5_tempStore, r9_blocksPerGroup
            // BLOCKS_INTO_GROUP < INODE_BLOCKS_PER_GROUP + 3 = IS IN INODE MAP
            cmp r9_blocksPerGroup, r8_inodeSize
            jge IsOutsideInodeMap1

                // r13_fsPointer % INODE_SIZE < INODE_SIZE - 2 = IS LAST DIRECT
                push r13_fsPointer
                mod r13_fsPointer, r13_fsPointer, r8_inodeSize
                sub r8_inodeSize, r8_inodeSize, 2
                cmp r13_fsPointer, r8_inodeSize
                pop r13_fsPointer
                jl WasLastDirectPointer1
                jmp WasNotLastDirectPointer1

            // if we aren't in the inode map
            IsOutsideInodeMap1:
                // r13_fsPointer % BLOCK_SIZE > BLOCK_SIZE - INODE_SIZE = IS LAST DIRECT
                sub r8_inodeSize, r6_blockSize, r8_inodeSize
                mod r6_blockSize, r13_fsPointer, r6_blockSize
                cmp r13_fsPointer, r8_inodeSize
                jg WasLastDirectPointer1

            // if this wasn't the last direct pointer
            WasNotLastDirectPointer1:
                add r13_fsPointer, r13_fsPointer, 2
                jmp CopyFromDataBlock


            // if this WAS the last direct pointer
            WasLastDirectPointer1:
                add r13_fsPointer, r13_fsPointer, 2
                pload_16 r13_fsPointer, [r13_fsPointer]
                jmp CopyFromDataBlock


    AllocationSuccess:
        return

    AllocationFail:
        imm r1_returnValue, 0
        return


    return


InitKernelProgram:
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

            pop FFFD_Args
            pop FFFD_Size
			jne FileNotFound


	FileNotFound:
        pop FFFD_FsAddress
        pop FFFD_Args
        pop FFFD_Size
		imm FFFD_InodeNumber, 0b1111111111111111
        imm FFFD_InodeGroupNumber, 0
		jmp END_FFFD
		
	FileFound:
        pop FFFD_FsAddress
		pop FFFD_Args
		pop FFFD_Size
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
		return
	
END_PGRM:
jmp END_PGRM


OnClockInterrupt:
	push r1
	imm r1, 0b11111111
	dstore r1, [0]
	pop r1
	iret
	
OnIretAVF:
	pop flags
	add flags, flags, 4
	push flags
	iret