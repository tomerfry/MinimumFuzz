format ELF64 executable 3

segment readable executable

entry start

SYS_PERF_EVENT_OPEN = 298
SYS_READ = 0
SYS_WRITE = 1
SYS_EXIT = 60

PERF_TYPE_SOFTWARE = 1
PERF_COUNT_SW_TASK_CLOCK = 1

start:
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, header_msg
    mov rdx, header_len
    syscall

    ; Setup perf counter
    call setup_perf
    mov [perf_fd], rax
    
    ; Do almost no work - just a few operations
    mov rcx, 10
simple_loop:
    add rax, rcx
    dec rcx
    jnz simple_loop
    
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, work_msg
    mov rdx, work_len
    syscall
    
    ; Read counter
    mov rax, SYS_READ
    mov rdi, [perf_fd]
    mov rsi, counter_value
    mov rdx, 8
    syscall
    
    ; Print result
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, result_msg
    mov rdx, result_len
    syscall
    
    mov rax, [counter_value]
    call print_number
    
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    
    mov rax, SYS_EXIT
    mov rdi, 0
    syscall

setup_perf:
    ; Clear attr
    mov rdi, perf_attr
    mov rcx, 128
    xor rax, rax
    rep stosb
    
    ; Set minimal fields
    mov dword [perf_attr], PERF_TYPE_SOFTWARE
    mov dword [perf_attr + 4], 128
    mov qword [perf_attr + 8], PERF_COUNT_SW_TASK_CLOCK
    
    ; Open perf event
    mov rax, SYS_PERF_EVENT_OPEN
    mov rdi, perf_attr
    mov rsi, 0
    mov rdx, -1
    mov r10, -1
    mov r8, 0
    syscall
    
    test rax, rax
    js error
    ret

print_number:
    ; Simple number printing
    mov rdi, num_buf + 19
    mov byte [rdi], 0
    mov rbx, 10
    
digit_loop:
    dec rdi
    xor rdx, rdx
    div rbx
    add dl, '0'
    mov [rdi], dl
    test rax, rax
    jnz digit_loop
    
    mov rax, num_buf + 19
    sub rax, rdi
    mov rdx, rax
    
    mov rax, SYS_WRITE
    mov rsi, rdi
    mov rdi, 1
    syscall
    ret

error:
    mov rax, SYS_WRITE
    mov rdi, 2
    mov rsi, error_msg
    mov rdx, error_len
    syscall
    
    mov rax, SYS_EXIT
    mov rdi, 1
    syscall

segment readable writable

perf_fd dq 0
counter_value dq 0
perf_attr rb 128
num_buf rb 20

header_msg db 'Ultra Minimal Perf:', 10
header_len = $ - header_msg

work_msg db 'Work completed, reading counter...', 10
work_len = $ - work_msg

result_msg db 'Task clock: '
result_len = $ - result_msg

error_msg db 'Perf setup failed', 10
error_len = $ - error_msg

newline db 10
