.global _start

.section .rodata
prefix:     .ascii "message address: 0x"
prefix_len = . - prefix

newline:    .ascii "\n"

.section .bss
.align 8
hexbuf:     .skip 16

.section .data
.align 8
timespec:
    .quad 10                 /* tv_sec */
    .quad 0                  /* tv_nsec */

msg:        .ascii "<TOKEN>\n"
msg_len = . - msg

.section .text
_start:
    /* write(1, prefix, prefix_len) */
    mov     $1, %rax         /* sys_write */
    mov     $1, %rdi         /* fd */
    lea     prefix(%rip), %rsi
    mov     $prefix_len, %rdx
    syscall

    /* r12 = address of msg */
    lea     msg(%rip), %r12

    /* convert r12 to 16 hex chars in hexbuf */
    lea     hexbuf(%rip), %r13
    mov     %r12, %r14
    mov     $16, %r15

hex_loop:
    mov     %r14, %rbx
    shr     $60, %rbx
    cmp     $9, %rbx
    jbe     hex_digit
    add     $('a' - 10), %rbx
    jmp     hex_store

hex_digit:
    add     $'0', %rbx

hex_store:
    movb    %bl, (%r13)
    inc     %r13
    shl     $4, %r14
    dec     %r15
    jne     hex_loop

    /* write(1, hexbuf, 16) */
    mov     $1, %rax
    mov     $1, %rdi
    lea     hexbuf(%rip), %rsi
    mov     $16, %rdx
    syscall

    /* write(1, "\n", 1) */
    mov     $1, %rax
    mov     $1, %rdi
    lea     newline(%rip), %rsi
    mov     $1, %rdx
    syscall

    /* nanosleep(&timespec, NULL) */
    mov     $35, %rax        /* sys_nanosleep */
    lea     timespec(%rip), %rdi
    xor     %rsi, %rsi
    syscall

    /* write(1, msg, msg_len) */
    mov     $1, %rax
    mov     $1, %rdi
    lea     msg(%rip), %rsi
    mov     $msg_len, %rdx
    syscall

    /* exit(0) */
    mov     $60, %rax        /* sys_exit */
    xor     %rdi, %rdi
    syscall
