.equ    outputBuffSize, 256
.equ    dataBufferSize, 64000
.equ    codeSize, 128000

.bss
    outputBuffer:   .space 256  #outputBuffSize
    dataPtr:        .quad 0     #ptr to dataBuffer
    codePtr:        .quad 0     #ptr to ass output
    brainfuck:      .quad 0     #ptr to brainfuck asciz

.text
    invArgCountOut: .asciz  "Argument count needs to be exactly 2.\n"

.include "assembler.s"
.global main
main:   #(int argC, char[] **argV) -> int
    pushq   %rbp
    movq    %rsp, %rbp

    /two arguments : exec_name fileName
    cmpq    $2, %rdi
    jne     invalidArgCount

    /push ptr to second argument on stack (fileName)
    pushq   8(%rsi)

    /alocate mem
    movq    $codeSize, %rdi
    call    allocExWrMem
    movq    %rax, codePtr

    /alocate mem
    movq    $dataBufferSize, %rdi
    call    allocExWrMem
    movq    %rax, dataPtr

    /openfile
    popq    %rdi
    call    openFile
    pushq   %rax

    /loading contents to memory
    movq    %rax, %rdi
    call    loadFile
    movq    %rax, brainfuck

    /closefile
    popq    %rdi
    call    closeFD

    /assemble
    movq    brainfuck, %rdi
    movq    codePtr, %rsi
    call    assemble

execute:
    movq    dataPtr, %rax
    leaq    outputBuffer, %rsi
    movq    $0, %rdx
    leaq    output, %r8
    leaq    print, %r9
    leaq    input, %r10
    call    *codePtr

    /exit
    movq    %rbp, %rsp
    popq    %rbp
    call    exit
//end

invalidArgCount:
    /error output
    leaq    invArgCountOut, %rdi
    movq    $0, %rax
    call    printf

    /exit with code -1
    movq    $-1, %rdi
    call    exit
