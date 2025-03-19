.equ    sys_read, 0
.equ    stdin, 0

.equ    sys_write, 1
.equ    stdout, 1

.equ    sys_open, 2
.equ    O_RDONLY, 0

.equ    sys_close, 3

.equ    sys_fstat, 5
.equ    fstat_size, 144
.equ    offset, 48 

.equ    sys_mmap, 9
.equ    MAP_SHARED, 0x1
.equ    PROT_READ, 0x1
.equ    PROT_WRITE, 0x2
.equ    PROT_EXEC, 0x4
.equ    MAP_ANON, 0x20

.equ    O_RDWR, 2
.equ    O_CREAT, 4

.equ    sys_exit, 60
#------------------------

.text
    test:       .asciz "mmap"
    test1:      .asciz "shm_open"
    shmName:    .asciz "/shared"
    openFileErrOut: .asciz  "There was an error opening the file\n"

/not necessary after all... ugh
openSharedMemSpace:
    pushq   %rbp
    movq    %rsp, %rbp

    leaq    shmName, %rdi   #name
    movq    $O_RDWR, %rsi   #flags
    orq     $O_CREAT, %rsi  #floags
    movq    $0, %rdx        #mode //(for fute access, will here be r/w because first time)
    call    shm_open

    leaq    test1, %rdi
    call    perror

    movq    %rbp, %rsp
    popq    %rbp
    ret

allocExWrMem:   #(int size) -> void *ptr
    pushq   %rbp
    movq    %rsp, %rbp

/*
    pushq   %rdi
    pushq   %rdi

    call    openSharedMemSpace
    popq    %rdi
    pushq   %rax
    
    movq    %rax, %rdi      #fd
    movq    -8(%rbp), %rsi  #length
    call    truncate
    
    popq    %r8                 #fd
    popq    %rsi                #length
*/

    movq    %rdi, %rsi          #length
    movq    $0, %rdi            #address
    movq    $PROT_READ, %rdx    #prot
    orq     $PROT_WRITE, %rdx   #prot
    orq     $PROT_EXEC, %rdx    #prot
    movq    $MAP_ANON, %r10     #flag
    orq     $MAP_SHARED, %r10   #flag
    movq    $0, %r8             #fd
    movq    $0, %r9             #offset
    movq    $sys_mmap, %rax
    syscall

/* only supported with C-lib I think
    cmpq    $-1, %rax
    jnz     retAlloc
    leaq    test, %rdi
    call    perror
*/

    movb    $0, (%rax) #writetest -> passes

retAlloc:    
    movq    %rbp, %rsp
    popq    %rbp
    ret

/*
print: #(address, count) -> void
    movq    %rsi, %rdx  #count
    movq    %rdi, %rsi  #address
    movq    $1, %rax    #sys_write
    movq    $1, %rdi    #stdout
    syscall
    ret
*/


getFileSize:    #(int FD) -> int #size in bytes #ASSUMING THE OFFSET OF st_size IS 48!!!
    pushq   %rbp
    movq    %rsp, %rbp

    subq    $fstat_size, %rsp  #allocating 144 bytes for fstat
    movq    %rsp, %rsi  #struct buffer
    movq    %rdi, %rdi  #FD
    movq    $sys_fstat, %rax
    syscall

    addq    $offset, %rsp
    movq    (%rsp), %rax #return st_size

    movq    %rbp, %rsp
    popq    %rbp
    ret


loadFile:   #(int fileDescriptor) -> *char[]
    pushq   %rbp
    movq    %rsp, %rbp

    pushq   %rdi
    call    getFileSize
    cmpq    $0, %rax
    je      emptyFile

    movq    $0, %rdi    #memAdr = null -> return any valid adress
    movq    %rax, %rsi  #length
    movq    $PROT_READ, %rdx    #mode
    movq    $MAP_SHARED, %r10    #flag
    popq    %r8         #FD from %rdi
    movq    $0, %r9     #offset for FD = 0
    movq    $sys_mmap, %rax    #9 = sys_mmap
    syscall

    movq    %rbp, %rsp
    popq    %rbp
    ret

emptyFile:  #return error code (file is empty)
    movq    $-1, %rax
    
    movq    %rbp, %rsp
    popq    %rbp
    ret


openFile:   #(*char[] name) -> int fileDescriptor    
    pushq   %rbp
    movq    %rsp, %rbp

    movq    $sys_open, %rax    # 2 = sys_open
    movq    %rdi, %rdi  # *char[] fileName
    movq    $O_RDONLY, %rsi    #flag 0 = O_RDONLY
    movq    $0, %rdx    #move 0 (-> mode omitted, only for file creation)
    syscall
    
    cmpq    $-2, %rax       #for some reason, exit code is -2 and not -1???
    je      fileOpenError

    movq    %rbp, %rsp
    popq    %rbp
    ret


closeFD:    #(int fileDescriptor) -> void
    movq    $sys_close, %rax    # 3 = sys_close
    movq    %rdi, %rdi  # fileDescriptor
    syscall
    ret


fileOpenError:
    /error output
    leaq    openFileErrOut, %rdi
    call    printf

    /exit with code -1
    movq    $-1, %rdi
    call    exit

