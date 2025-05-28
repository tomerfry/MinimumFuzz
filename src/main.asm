; hello.asm - Hello World in FASM2 for Linux x86-64

format ELF64 executable 3
entry start

segment readable executable

start:
    ; write syscall
    mov rax, 1          ; syscall number for write
    mov rdi, 1          ; file descriptor 1 (stdout)
    mov rsi, message    ; pointer to message
    mov rdx, msg_len    ; message length
    syscall

    ; exit syscall
    mov rax, 60         ; syscall number for exit
    xor rdi, rdi        ; exit code 0
    syscall

segment readable

message db 'Hello, World!', 10  ; 10 is newline character
msg_len = $ - message
