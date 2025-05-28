format ELF64 executable 3
entry start

; System call numbers for x86_64 Linux
SYS_WRITE       = 1
SYS_OPEN        = 2
SYS_CLOSE       = 3
SYS_FORK        = 57
SYS_EXECVE      = 59
SYS_EXIT        = 60
SYS_WAIT4       = 61
SYS_TIME        = 201
SYS_DUP2        = 33

; File flags
O_WRONLY        = 1
O_CREAT         = 64
O_TRUNC         = 512

; File permissions
S_IRUSR         = 256
S_IWUSR         = 128
S_IRGRP         = 32
S_IROTH         = 4

segment readable writeable

; All data in writeable segment
target_prog     rb 256
filename        db 'fuzz_input.dat', 0
dev_null        db '/dev/null', 0

; Buffers
buffer_size     = 1024
fuzz_buffer     rb buffer_size
temp_buffer     rb 64
status_buffer   dd 0        ; Dedicated 4-byte status buffer

; Target argv
target_argv     dq 0, 0, 0

; Messages (simplified)
msg_start       db 'Simple Linux Fuzzer Started', 10, 'Target: ', 0
msg_iter        db 'Iteration ', 0
msg_ok          db ' - OK', 10, 0
msg_crash       db ' - CRASH!', 10, 0
msg_usage       db 'Usage: ./fuzzer <program>', 10, 0

; Counters
iteration       dq 1
seed           dq 12345

segment readable executable

start:
    ; Simple argc check - stack has [argc][argv0][argv1]...
    pop rax                 ; get argc
    cmp rax, 2
    jl usage_exit
    
    ; Skip argv[0], get argv[1] (target program)
    add rsp, 8              ; skip argv[0]
    pop rsi                 ; get argv[1]
    mov rdi, target_prog
    call simple_strcpy
    
    ; Setup target argv
    mov rax, target_prog
    mov [target_argv], rax
    mov rax, filename
    mov [target_argv + 8], rax
    mov qword [target_argv + 16], 0
    
    ; Print start message
    mov rsi, msg_start
    call print_str
    mov rsi, target_prog
    call print_str
    call print_newline
    
    ; Initialize seed
    mov rax, SYS_TIME
    mov rdi, 0
    syscall
    mov [seed], rax

main_loop:
    ; Print iteration (simple way)
    mov rsi, msg_iter
    call print_str
    call print_simple_number
    
    ; Generate random data
    call generate_fuzz_data
    
    ; Write to file
    call write_to_file
    
    ; Execute target
    call run_target
    
    ; Next iteration
    inc qword [iteration]
    
    ; Simple delay
    mov rcx, 100000
delay_loop:
    nop
    loop delay_loop
    
    jmp main_loop

usage_exit:
    mov rsi, msg_usage
    call print_str
    mov rax, SYS_EXIT
    mov rdi, 1
    syscall

; Very simple number printing - print full number
print_simple_number:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    
    mov rax, [iteration]
    mov rsi, temp_buffer
    add rsi, 19             ; Point to end of buffer (use as scratch space)
    mov rbx, 10
    mov rcx, 0
    
    ; Handle zero case
    test rax, rax
    jnz convert_digits
    mov byte [rsi], '0'
    dec rsi
    inc rcx
    jmp print_digits
    
convert_digits:
    ; Convert number to ASCII (backwards)
    xor rdx, rdx
    div rbx
    add dl, '0'
    mov [rsi], dl
    dec rsi
    inc rcx
    test rax, rax
    jnz convert_digits
    
print_digits:
    ; Print the number
    inc rsi                 ; Point to first digit
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rdx, rcx            ; Number of digits
    syscall
    
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

generate_fuzz_data:
    push rax
    push rcx
    push rsi
    
    ; Simple LCG
    mov rsi, fuzz_buffer
    mov rcx, buffer_size
    
fuzz_loop:
    mov rax, [seed]
    imul rax, 1103515245
    add rax, 12345
    mov [seed], rax
    
    mov [rsi], al
    inc rsi
    loop fuzz_loop
    
    pop rsi
    pop rcx
    pop rax
    ret

write_to_file:
    push rax
    push rdi
    push rsi
    push rdx
    
    ; Open file
    mov rax, SYS_OPEN
    mov rdi, filename
    mov rsi, O_WRONLY or O_CREAT or O_TRUNC
    mov rdx, S_IRUSR or S_IWUSR or S_IRGRP or S_IROTH
    syscall
    
    mov rdi, rax    ; fd
    
    ; Write data
    mov rax, SYS_WRITE
    mov rsi, fuzz_buffer
    mov rdx, buffer_size
    syscall
    
    ; Close
    mov rax, SYS_CLOSE
    syscall
    
    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret

run_target:
    push rax
    push rdi
    push rsi
    push rdx
    
    ; Fork
    mov rax, SYS_FORK
    syscall
    
    cmp rax, 0
    je child
    
    ; Parent - wait
    mov rdi, rax    ; child pid
    mov rsi, status_buffer  ; status
    mov rdx, 0
    mov r10, 0
    mov rax, SYS_WAIT4
    syscall
    
    ; Check status (simplified)
    mov eax, [status_buffer]
    test eax, eax
    jz run_ok
    
    mov rsi, msg_crash
    call print_str
    jmp run_done
    
run_ok:
    mov rsi, msg_ok
    call print_str
    jmp run_done
    
child:
    ; Redirect stdout/stderr to /dev/null
    mov rax, SYS_OPEN
    mov rdi, dev_null
    mov rsi, O_WRONLY
    mov rdx, 0
    syscall
    
    mov r8, rax
    
    ; Redirect stdout
    mov rax, SYS_DUP2
    mov rdi, r8
    mov rsi, 1
    syscall
    
    ; Redirect stderr
    mov rax, SYS_DUP2
    mov rdi, r8
    mov rsi, 2
    syscall
    
    ; Exec
    mov rax, SYS_EXECVE
    mov rdi, target_prog
    mov rsi, target_argv
    mov rdx, 0
    syscall
    
    ; Exit if exec failed
    mov rax, SYS_EXIT
    mov rdi, 1
    syscall

run_done:
    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret

; Helper functions
simple_strcpy:
    push rax
strcpy_loop:
    lodsb
    stosb
    test al, al
    jnz strcpy_loop
    pop rax
    ret

print_str:
    push rax
    push rdi
    push rdx
    
    mov rdi, rsi
    call get_strlen
    
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rdx, rcx
    syscall
    
    pop rdx
    pop rdi 
    pop rax
    ret

get_strlen:
    push rsi
    mov rcx, 0
len_loop:
    cmp byte [rsi], 0
    je len_done
    inc rsi
    inc rcx
    jmp len_loop
len_done:
    pop rsi
    ret

print_newline:
    push rax
    push rdi
    push rsi
    push rdx
    
    mov [temp_buffer], byte 10
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, temp_buffer
    mov rdx, 1
    syscall
    
    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret
