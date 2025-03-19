/*  assemble(char[] brainfuck, void *dest) -> int   //exit code
     -  takes a pointer to a piece of zero-terminated brainfuck and
        assembles it to machinecode which it stores at *dest
     -  /jmp's occur to immediate values meaning these are FIXED PLACES
        in memory, meaning once the code is assembled, there is no movin
        this shit.
     -  we use the stack for storing start loop addresses concurently meaning
        we cant put return adresses on there causes then stuff wouldn't be concurent
        anymore
     -  DONT USE these registers during ASSEMBLY:
        {rbx:brainfuck; r13:ouptut; r12:funcTable}
*/

/*  execution:
     -  Following registers are reserver and thus may not be altered without
        restoring their state after modifying them:
        {%rax:dataPtr; %rsi:*outputBuffer; %rdx:outBuffCount; %rbx:*output; r8:print}
     -  following are inconsistent:
        {%rdi;%rcx}
*/

/* char table:
    >   62  0x3E
    <   60  0x3C
    +   43  0x2B
    -   45  0x2D
    .   46
    ,   44
    [   91  0x5B
    ]   93  0x5D
*/

/* machinecode table: (old)
    .equ addRAX:        0x48 05 00 00 00 00 #B[3-0] imm val
    .equ addMRAX:       0x48 80 00 00       #B0 imm val
    .equ jmpOFS:        0xE9 00 00 00 00    #B[3-0] offset
    .equ movzxMRAXRCX:  0x48 0F 08          #N/A
    .equ testbCL:       0x84 C9             #N/A
    .equ jccZF:         0x0F 84 00 00 00 00 #B[3-0] offset
*/

/machineCodeTable: (updated) (converted to multiples of two) (+=append;-=overwrite)
    .equ addRAX,        0x0548      #+ 4B imm val (x)
    .equ addMRAX,       0x00008048  #- 1B imm val (x)
    .equ jmpOFS,        0xE9        #+ 4B imm val (offset)
    .equ movzxMRAXRCX,  0x08B60F48  #(N/A)
    .equ testbCL,       0xC984      #(N/A)
    .equ jccZF,         0x840F      #+ 4B imm vall (offset)
    .equ callOFS,       0xE8        #+ 4B imm vall (offset)
    .equ callR8,        0xD0FF49    #(N/A)
    .equ callR9,        0xD1FF49    #(N/A)
    .equ callR10,       0xD2FF49    #(N/A)
    .equ return,        0xC3        #(N/A)
    .equ movb0,         0x0000C648  #(N/A)
    .equ addbCLOFSMRAX, 0x00480048  #- 1/1B imm val (offset)
    .equ subbCLOFSMRAX, 0x00482848  #- 1/1B imm val (offset)
/end

/* charFuncTable:
    .quad   endOfFile   #0
    .fill   42, 8, assLoop
    .quad   incData #43 +
    .quad   scanC    #44 ,
    .quad   decData #45 -
    .quad   printC   #46 .
    .space 104      #47
    .quad   decPtr  #60 <
    .space 8        #61
    .quad   incPtr  #62 >
    .space 224      #63
    .quad   loopSta #91 [
    .space 8        #92
    .quad   loopEnd #93 ]
*/

/* patters:
    (/) movb $0, (%rax)                     [-]
    ()  addb (%rax), x(%rax); clear(%rax)   [->x+<x]
    ()  subb (%rax), x(%rax); clear(%rax)   [->x-<x]
    ()  movb (%rax), x(%rax); clear(%rax)   [-]<x[->x+<x]
    (/) *ignore*                            ][-]

    we load 4 chars, this allows us to eliminate {'[-]';'][-]'}
    we test -, we test -] or >x+<x] or <x+>x] or >x-<x] or <x->x]
*/

.equ    charFuncTableSize, 256     # *8 = 2048B
.equ    newL, 10
.equ    lineF, 13

.bss
    charFuncTable:  .quad 0

.include "syscalls.s"

assemble:
    /prologue
    pushq   %rbp
    pushq   %rbx
    pushq   %r12
    pushq   %r13
    movq    %rsp, %rbp

    /initialising registers
    movq    %rdi, %rbx          #using %rbx as *char
    movq    %rsi, %r13          #using %r13 as *dest

    /initialising lookup table
    call    initcharFuncTable
    movq    charFuncTable, %r12 #using %r12 as *funcTable

/main traversing loop
assLoop:
    movzbq  (%rbx), %rdi    #next char
    incq    %rbx            #update ptr
    jmp     *(%r12, %rdi, 8) #call func corresponding to char // '*' because otherwise AT&T will be mad >:( // jmp because we jmp back for stack reasons
    /previous jmp always returns to assLoop

assEnd:
    movq    %rbp, %rsp
    popq    %r13
    popq    %r12
    popq    %rbx
    popq    %rbp
    ret
//end

/*  different char functions:
    for efficiency reasons, we're trying not to alter
    registers: {%rbx, %r12, %r13, %rdi}
    during method calls so we dont have to pop and push them
    registers we alter: {%rax, %rdx}
*/
incPtr:
    call    findAmount

    movw    $addRAX, (%r13)     #2B machine code
    movl    %eax, 2(%r13)       #4B imm val
    addq    $6, %r13            #move 6

    jmp     assLoop

decPtr:
    call    findAmount

    negl    %eax
    movw    $addRAX, (%r13)     #2B mc
    movl    %eax, 2(%r13)       #4B imm V
    addq    $6, %r13            #6B total

    jmp     assLoop

incData:
    call    findAmount

    movl    $addMRAX, (%r13)    #3B mc
    movb    %al, 3(%r13)        #1B imm V   //suposing no more than 255 but that would be stupid cause wrap around (max is 255)
    addq    $4, %r13            #4B total

    jmp     assLoop

decData:
    call    findAmount

    negl    %eax
    movl    $addMRAX, (%r13)    #3B mc
    movb    %al, 3(%r13)        #1B imm V   //suposing no more than 255 but that would be stupid cause wrap around (max is 255)
    addq    $4, %r13            #4B total

    jmp     assLoop


/(legacy) call <output>      //causing issues because mc is at top of mem and output at bottom meaning offset>32-bit val
/pushq %rip
/movq $output, %rip
printC:
    movl    $callR8, (%r13)    #3B mc
    addq    $3, %r13    

    jmp     assLoop


/call a precompiled function which we link to the file
scanC:
    movl    $callR10, (%r13)    #3B mc
    addq    $3, %r13

    jmp     assLoop


/* assembly:
    1)  movzbq  (%rax), %rcx    <- start, at loop end we jmp to this
    2)  testb   %cl, %cl
    3)  jz      $offset         -> firt instruction after loop end (jmp start)

    we push adress of 1st instruction we jmp to later so we can calculate offset
    we use same address to calculate position we have to overwrite 7(%13)
*/
loopSta:
    #check if we are actualy encoding a loop or maybe something else?
    movzwq  (%rbx), %rdi    #loads -] maybe
    cmpb    $45, %dil       #c[0] == '-' ?
    jne     normLoop

    #might be dealing with a pattern
    cmpw    $0x5D2D, %di    #== '-]' ?
    je      nullLoop

    pushq   %rbx
    call    findAddSub
    movq    $0, %rax        #we skip this optimization cause it's broken and after 4 hours I still don't know how to fix this
    test    %rax, %rax
    jz      failLoopSta

notFail:
    /remove rbx from stack
    popq    %rsi

    /movzbq (%rax), %rcx
    movl    $movzxMRAXRCX, (%r13)   # 4B mc

    /movb   $0, (%rax)
    movl    $movb0, 4(%r13)         #4B mc

    / (rax/)eax offset; rdi 0+ / 1-
    test    %rdi, %rdi
    jnz     subtract

addition:
    /addb   %rcx, off(%rax)
    movl    $addbCLOFSMRAX, 8(%r13) # 3B mc
    movb    %al, 11(%r13)           # 1B offset

    addq    $12, %r13
    jmp     assLoop

subtract:
    /subb   %rcx, off(%rax)
    movl    $subbCLOFSMRAX, 8(%r13) #3B mc
    movb    %al, 11(%r13)           #1B offset

    addq    $12, %r13
    jmp     assLoop    

failLoopSta:
    popq    %rbx        #restore rbx and continue as with normal loop

normLoop:
    #normal loop
    pushq   %r13                    #instruction we jmp to

    movl    $movzxMRAXRCX, (%r13)   #4B mc  //(1)
    movw    $testbCL, 4(%r13)       #2B mc  //(2)
    movw    $jccZF, 6(%r13)         #2B mc  //(3)
    #4B imm val

    addq    $12, %r13               #total=12B (4+2+2+4)
    jmp     assLoop

nullLoop:
    /check for moveLoop (basically a ptr inc with add/sub)  // not implemented cause pay-of wouldn't be worth it

    /implement nullLoop
    movl    $movb0, (%r13)          #3B mc
    movb    $0, 3(%r13)             #1B imm val

    addq    $2, %rbx                #skipp next 2 chars [ (rbx)-] -> [-](rbx)

    addq    $4, %r13
    jmp     assLoop

moveLoop:

/check for [ (rbx)-<>x+><x]
findAddSub: #(rbx) -> int // RBX NOT HANDLED IN CASE OF FAIL    // fail:RAX=0 // RAX=offset ; rdi=0 for '+' ; rdi=1 for '-' ; RBX=first char after
    pushq   %rbp    
    pushq   %r14            # forward/backward
    pushq   %r15            # + / -
    movq    %rsp, %rbp
    
    / [- ?
    movw    -1(%rbx), %ax
    cmpw    $0x2D5B, %ax
    jne     findAddSubFail

    / </> ? amount?
    addq    $2, %rbx        #rbx points to first char after [-< because thats how we made find amount
    movb    -1(%rbx), %dil    #load next char
    call    findAmount      #rax contains nr of forward or backward, rbx points to + -
    movzbq  -1(%rbx), %r14  
    subq    $61, %r14       # -1 if < ; +1 if >

    / +/- ?
    movq    $0, %r15        # return 0 if +
    cmpb    $43, (%rbx)
    je      pm

    movq    $1, %r15        # return -1 if -
    cmpb    $45, (%rbx)
    jne     findAddSubFail
pm:
    addq    $2, %rbx       #rbx points to first char after +/-

    / >/< ? amount?
    pushq   %rax            # first offset
    movb    -1(%rbx), %dil  # next char
    call    findAmount      # rbx points to first char after hopefully ]
    popq    %rdx
    cmpq    %rax, %rdx      #see if first and last offset are equal
    jne     findAddSubFail
    imul    %r14, %rax      # *-1 if < ; *1 if > 

    / ] ?
    cmpb    $0x5D, (%rbx)   # ]
    jne     findAddSubFail
    addq    $1, %rbx        # point to after ]
    movq    %r15, %rdi      # return 0 or 1
    jmp     retFindAs       #succes!

findAddSubFail:
    movq    $0, %rax

retFindAs:
    movq    %rbp, %rsp
    popq    %r15
    popq    %r14
    popq    %rbp
    ret


/* assembly:
    jmp     $offset         -> start

    pop address jz
    pop addres start
    calculate offset end->start

    calculate offset start->end
    write at address jz
*/
loopEnd:
    /calculate offset
    popq    %rax
    movq    %rax, %rdx      #copy of loop start because we also have to modify that
    addq    $5, %r13        #addres RIP will be pointing to first instruction after jmp (5B)
    subq    %r13, %rax      #rax := rax - r13

    /loop end (create)
    movb    $jmpOFS, -5(%r13)   #1B mc
    movl    %eax, -4(%r13)      #offset should be 32bit val (ofs<4,294,967,296) (trust me it is)

    /loop start (insert offset)
    negq    %rax            #jmp forward so pos value
    subq    $12, %rax       #offset to jmp forward will be <loopstart.size> (12B) less
    movl    %eax, 8(%rdx)   #overwrite previously empty offset for jmp at loopstart
    #now the loop has been finished, we can check for '[-]' after this, and if it is there, skip it because when we exit from a loop, it's because our current cell is 0, so a 0 loop makes no sense

    /ignore [-] if ][-]
    movl    -1(%rbx), %edi  #might load ][-] = 93 91 45 93 = 0x5D 5B 2D 5D
    cmpl    $0x5D2D5B5D, %edi
    jne     assLoop

    addq    $3, %rbx        #skip next 3 chars
    jmp     assLoop

/insert return statement
endOfFile:
    movl    $callR9, (%r13)     #3B mc
    movb    $return, 3(%r13)    #1B mc
    addq    $4, %r13

    jmp     assEnd
//end


/other helpful functions
findAmount: #(char) -> int  //returns amount of occurences of said char, updates ptr to first char that does not equal input
    movl    $1, %eax    #first char is already found
faLoop:
    movb    (%rbx), %sil    #load next char

    cmpb    %dil, %sil      #next char is same?
    je      nextC

    /for newline and linefeed
    cmpb    $newL, %sil
    je      skipNL
    cmpb    $lineF, %sil
    je      skipNL

    /new char did not equal and wasnt NL/LF
    jmp     faRet

nextC:
    incq    %rbx            #update ptr to next char
    incl    %eax            #update result
    jmp     faLoop          #repeat

skipNL:   #for \r and \n
    incq    %rbx
    jmp     faLoop

faRet: 
    ret


/initiates the lookup table, linking brainfuck chars to functions and others to skip
initcharFuncTable:
    /allocate memory
    movq    $charFuncTableSize, %rdi
    imul    $8, %rdi
    call    allocExWrMem
    movq    %rax, charFuncTable

    /fill memory with *assLoop
    movq    $charFuncTableSize, %rdi
    leaq    assLoop, %rsi
charFuncTableLoop:
    decq    %rdi
    cmpq    $0, %rdi
    jl      assignValues

    movq    %rsi, (%rax, %rdi, 8)
    jmp     charFuncTableLoop

assignValues:
    leaq    endOfFile, %rdi #0
    movq    %rdi, (%rax)
    leaq    incData, %rsi   #43
    movq    %rsi, 344(%rax)
    leaq    scanC, %rdi     #44
    movq    %rdi, 352(%rax)
    leaq    decData, %rsi   #45
    movq    %rsi, 360(%rax)
    leaq    printC, %rdi    #46
    movq    %rdi, 368(%rax)
    leaq    decPtr, %rsi    #60
    movq    %rsi, 480(%rax)
    leaq    incPtr, %rdi    #62
    movq    %rdi, 496(%rax)
    leaq    loopSta, %rsi   #91
    movq    %rsi, 728(%rax)
    leaq    loopEnd, %rdi   #93
    movq    %rdi, 744(%rax)

    ret


/read 1 char from terminal
input:
    pushq   %rbp
    pushq   %rax
    pushq   %rdi
    pushq   %rsi
    pushq   %rdx
    movq    %rsp, %rbp

    movq    $stdin, %rdi    #fd
    movq    %rax, %rsi      #*char
    movq    $1, %rdx        #count
    movq    $sys_read, %rax #read
    syscall

    movq    %rbp, %rsp
    popq    %rdx
    popq    %rsi
    popq    %rdi
    popq    %rax
    popq    %rbp
    ret

/function called from brainfuck, handles output
output:
    /store char in buff and inc count
    movb    (%rax), %dil
    movb    %dil, (%rsi, %rdx, 1)
    incq    %rdx

    /buff full?
    cmpq    $outputBuffSize, %rdx
    jl      retOut

print:
    pushq   %rax    #because %rax needs to be consistent and we're about to alter it

    movq    $sys_write, %rax
    movq    $stdout, %rdi
    #movq   %rsi, %rsi
    #movq   %rdx, %rdx
    syscall

    movq    $0, %rdx
    popq    %rax    #restoring %rax

retOut:
    ret
//end

