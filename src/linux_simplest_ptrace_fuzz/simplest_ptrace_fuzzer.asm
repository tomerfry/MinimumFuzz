format ELF64 executable 3

segment readable executable

entry start

; System calls
SYS_PTRACE = 101
SYS_WAIT4 = 61
SYS_FORK = 57
SYS_EXECVE = 59
SYS_WRITE = 1
SYS_EXIT = 60
SYS_OPEN = 2
SYS_CLOSE = 3

; ptrace requests
PTRACE_TRACEME = 0
PTRACE_PEEKUSER = 3
PTRACE_SINGLESTEP = 9

; Register offsets (x86_64)
RIP_OFFSET = 128

start:
    ; Check arguments
    cmp qword [rsp], 2
    jl usage_error
    
    ; Get target program from argv[1]
    mov rax, qword [rsp + 16]
    mov qword [target_program], rax
    
    ; Print header
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, header_msg
    mov rdx, header_len
    syscall
    
    ; Print target name
    mov rdi, qword [target_program]
    call print_string
    call print_newline
    
    ; Initialize coverage tracking
    call init_coverage
    
    ; Fork process
    mov rax, SYS_FORK
    syscall
    
    test rax, rax
    jz child_process
    js fork_error
    
    ; Parent: trace the child
    mov qword [child_pid], rax
    call trace_execution
    call print_results
    
    mov rax, SYS_EXIT
    mov rdi, 0
    syscall

child_process:
    ; Child: enable tracing and exec target
    mov rax, SYS_PTRACE
    mov rdi, PTRACE_TRACEME
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    syscall
    
    ; Exec target program
    mov rax, SYS_EXECVE
    mov rdi, qword [target_program]
    mov rsi, child_argv
    mov rdx, 0                 ; inherit environment
    syscall
    
    ; Should not reach here
    mov rax, SYS_EXIT
    mov rdi, 1
    syscall

init_coverage:
    ; Clear coverage bitmap
    mov rdi, coverage_bitmap
    mov rcx, BITMAP_SIZE
    xor rax, rax
    rep stosb
    
    ; Initialize counters
    mov qword [total_instructions], 0
    mov qword [unique_blocks], 0
    ret

trace_execution:
    ; Wait for child to stop initially
    call wait_child
    
    mov qword [trace_count], 0

trace_loop:
    ; Limit tracing to prevent hanging
    inc qword [trace_count]
    cmp qword [trace_count], MAX_TRACE_COUNT
    jge trace_done
    
    ; Get current instruction pointer
    call get_rip
    
    ; Record this address for coverage
    mov rax, qword [current_rip]
    call record_address
    
    ; Single step
    mov rax, SYS_PTRACE
    mov rdi, PTRACE_SINGLESTEP
    mov rsi, qword [child_pid]
    mov rdx, 0
    mov r10, 0
    syscall
    
    ; Wait for child
    call wait_child
    
    ; Check if child is still alive
    mov rax, qword [wait_status]
    test rax, 0xFF
    jz trace_done              ; Child exited
    
    ; Show progress every 1000 instructions
    mov rax, qword [trace_count]
    mov rdx, 0
    mov rbx, 1000
    div rbx
    cmp rdx, 0
    jne trace_loop
    
    ; Print progress dot
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, dot_char
    mov rdx, 1
    syscall
    
    jmp trace_loop

trace_done:
    call print_newline
    ret

get_rip:
    ; Get RIP register using PTRACE_PEEKUSER
    mov rax, SYS_PTRACE
    mov rdi, PTRACE_PEEKUSER
    mov rsi, qword [child_pid]
    mov rdx, RIP_OFFSET        ; RIP offset in user area
    mov r10, 0
    syscall
    
    ; Store RIP
    mov qword [current_rip], rax
    ret

record_address:
    ; Simple coverage tracking using bitmap
    ; Hash the address into bitmap index
    mov rbx, rax
    shr rbx, 4                 ; Divide by 16 to group nearby addresses
    and rbx, BITMAP_MASK       ; Keep within bitmap bounds
    
    ; Check if this bit is already set
    movzx rcx, byte [coverage_bitmap + rbx]
    test rcx, rcx
    jnz already_seen
    
    ; New coverage!
    mov byte [coverage_bitmap + rbx], 1
    inc qword [unique_blocks]
    
already_seen:
    inc qword [total_instructions]
    ret

wait_child:
    mov rax, SYS_WAIT4
    mov rdi, qword [child_pid]
    mov rsi, wait_status
    mov rdx, 0
    mov r10, 0
    syscall
    ret

print_results:
    ; Print coverage summary
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, results_header
    mov rdx, results_header_len
    syscall
    
    ; Print total instructions
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, total_msg
    mov rdx, total_msg_len
    syscall
    
    mov rax, qword [total_instructions]
    call print_number
    call print_newline
    
    ; Print unique blocks
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, unique_msg
    mov rdx, unique_msg_len
    syscall
    
    mov rax, qword [unique_blocks]
    call print_number
    call print_newline
    
    ; Print coverage percentage
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, coverage_msg
    mov rdx, coverage_msg_len
    syscall
    
    ; Calculate percentage: (unique_blocks * 100) / BITMAP_SIZE
    mov rax, qword [unique_blocks]
    mov rbx, 100
    mul rbx
    mov rbx, BITMAP_SIZE
    div rbx
    
    call print_number
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, percent_msg
    mov rdx, percent_msg_len
    syscall
    
    ; Print usage note
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, usage_note
    mov rdx, usage_note_len
    syscall
    ret

print_string:
    ; Print null-terminated string at RDI
    push rdi
    call strlen
    mov rdx, rax               ; length
    pop rsi                    ; string
    mov rax, SYS_WRITE
    mov rdi, 1
    syscall
    ret

strlen:
    ; Calculate string length
    push rdi
    xor rax, rax
strlen_loop:
    cmp byte [rdi], 0
    je strlen_done
    inc rax
    inc rdi
    jmp strlen_loop
strlen_done:
    pop rdi
    ret

print_number:
    ; Print number in RAX
    push rax
    push rbx
    push rcx
    push rdx
    
    mov rdi, number_buffer + 19
    mov byte [rdi], 0
    mov rbx, 10
    
convert_loop:
    dec rdi
    xor rdx, rdx
    div rbx
    add dl, '0'
    mov [rdi], dl
    test rax, rax
    jnz convert_loop
    
    ; Print the number
    mov rax, number_buffer + 19
    sub rax, rdi
    mov rdx, rax               ; length
    mov rax, SYS_WRITE
    mov rsi, rdi               ; string
    mov rdi, 1                 ; stdout
    syscall
    
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

print_newline:
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    ret

usage_error:
    mov rax, SYS_WRITE
    mov rdi, 2
    mov rsi, usage_msg
    mov rdx, usage_msg_len
    syscall
    jmp exit_error

fork_error:
    mov rax, SYS_WRITE
    mov rdi, 2
    mov rsi, fork_error_msg
    mov rdx, fork_error_msg_len
    syscall

exit_error:
    mov rax, SYS_EXIT
    mov rdi, 1
    syscall

segment readable writable

; Constants
BITMAP_SIZE = 4096
BITMAP_MASK = 4095
MAX_TRACE_COUNT = 50000        ; Limit to prevent hanging

; Process information
child_pid dq 0
wait_status dq 0
target_program dq 0
child_argv dq 0, 0             ; Simple argv

; Coverage tracking
coverage_bitmap rb BITMAP_SIZE
total_instructions dq 0
unique_blocks dq 0
trace_count dq 0
current_rip dq 0

; Buffers
number_buffer rb 20

; Messages
header_msg db 'Coverage Tracer - Target: '
header_len = $ - header_msg

results_header db 10, '=== Coverage Results ===', 10
results_header_len = $ - results_header

total_msg db 'Total instructions: '
total_msg_len = $ - total_msg

unique_msg db 'Unique code blocks: '
unique_msg_len = $ - unique_msg

coverage_msg db 'Coverage: '
coverage_msg_len = $ - coverage_msg

percent_msg db '%', 10
percent_msg_len = $ - percent_msg

usage_note db 10, 'Use this metric to compare fuzzing inputs!', 10, 'Higher unique_blocks = better coverage', 10
usage_note_len = $ - usage_note

usage_msg db 'Usage: ./coverage_tracer <program>', 10, 'Example: ./coverage_tracer /bin/echo', 10
usage_msg_len = $ - usage_msg

fork_error_msg db 'Error: Fork failed', 10
fork_error_msg_len = $ - fork_error_msg

dot_char db '.'
newline db 10
