.global _start

.section .rodata
prefix:     .ascii "message address: 0x"
prefix_len = . - prefix

newline:    .ascii "\n"

.section .bss
.align 3
hexbuf:     .skip 16

.section .data
.align 3
timespec:
    .xword 10                 // tv_sec
    .xword 0                  // tv_nsec

msg:        .ascii "<TOKEN>\n"
msg_len = . - msg

.section .text
_start:
    // write(1, prefix, prefix_len)
    mov     x0, #1
    adr     x1, prefix
    mov     x2, #prefix_len
    mov     x8, #64           // sys_write
    svc     #0

    // x19 = address of msg
    adr     x19, msg

    // convert x19 to 16 hex chars in hexbuf
    adr     x20, hexbuf
    mov     x21, x19
    mov     x22, #16

hex_loop:
    lsr     x23, x21, #60
    cmp     x23, #9
    ble     hex_digit
    add     x23, x23, #'a' - 10
    b       hex_store
hex_digit:
    add     x23, x23, #'0'
hex_store:
    strb    w23, [x20], #1
    lsl     x21, x21, #4
    subs    x22, x22, #1
    b.ne    hex_loop

    // write(1, hexbuf, 16)
    mov     x0, #1
    adr     x1, hexbuf
    mov     x2, #16
    mov     x8, #64
    svc     #0

    // write(1, "\n", 1)
    mov     x0, #1
    adr     x1, newline
    mov     x2, #1
    mov     x8, #64
    svc     #0

    // nanosleep(&timespec, NULL)
    adr     x0, timespec
    mov     x1, #0
    mov     x8, #101          // sys_nanosleep
    svc     #0

    // write(1, msg, msg_len)
    mov     x0, #1
    adr     x1, msg
    mov     x2, #msg_len
    mov     x8, #64
    svc     #0

    // exit(0)
    mov     x0, #0
    mov     x8, #93           // sys_exit
    svc     #0
