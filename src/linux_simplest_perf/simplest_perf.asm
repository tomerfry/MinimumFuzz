format ELF64 executable 3

segment readable executable

entry start

; System call numbers for x86_64
SYS_PERF_EVENT_OPEN = 298
SYS_READ = 0
SYS_WRITE = 1
SYS_EXIT = 60

; perf_event_attr structure offsets
PERF_ATTR_SIZE = 128
PERF_TYPE_SOFTWARE = 1
PERF_COUNT_SW_PAGE_FAULTS = 2
PERF_COUNT_SW_CONTEXT_SWITCHES = 3
PERF_COUNT_SW_TASK_CLOCK = 1

start:
    ; Print header
    mov rax, SYS_WRITE
    mov rdi, 1                  ; stdout
    mov rsi, header_msg
    mov rdx, header_len
    syscall

    ; Try software events (less restricted)
    call setup_perf_attr_page_faults
    call create_perf_event
    cmp rax, 0
    js perf_error
    mov [page_faults_fd], rax
    
    call setup_perf_attr_context_switches
    call create_perf_event
    cmp rax, 0
    js perf_error
    mov [context_switches_fd], rax
    
    ; Perform some work to measure
    call do_work
    
    ; Read performance counters
    call read_counters
    
    ; Print results
    call print_results
    
    ; Exit
    mov rax, SYS_EXIT
    mov rdi, 0
    syscall

setup_perf_attr_page_faults:
    ; Clear the perf_event_attr structure
    mov rdi, perf_attr
    mov rcx, PERF_ATTR_SIZE
    xor rax, rax
    rep stosb
    
    ; Set up for page faults (software event)
    ; Use correct perf_event_attr layout
    mov dword [perf_attr], PERF_TYPE_SOFTWARE       ; type (u32)
    mov dword [perf_attr + 4], PERF_ATTR_SIZE       ; size (u32)
    mov qword [perf_attr + 8], PERF_COUNT_SW_PAGE_FAULTS  ; config (u64)
    mov qword [perf_attr + 16], 0                   ; sample_period (u64)
    mov qword [perf_attr + 24], 0                   ; sample_type (u64)
    mov qword [perf_attr + 32], 0                   ; read_format (u64)
    mov qword [perf_attr + 40], 0                   ; flags (u64) - disabled=0, inherit=0
    ret

setup_perf_attr_context_switches:
    mov rdi, perf_attr
    mov rcx, PERF_ATTR_SIZE
    xor rax, rax
    rep stosb
    
    mov dword [perf_attr], PERF_TYPE_SOFTWARE
    mov dword [perf_attr + 4], PERF_ATTR_SIZE
    mov qword [perf_attr + 8], PERF_COUNT_SW_CONTEXT_SWITCHES
    mov qword [perf_attr + 16], 0
    mov qword [perf_attr + 24], 0
    mov qword [perf_attr + 32], 0
    mov qword [perf_attr + 40], 0
    ret

create_perf_event:
    mov rax, SYS_PERF_EVENT_OPEN
    mov rdi, perf_attr          ; attr
    mov rsi, 0                  ; pid (0 = current process)
    mov rdx, -1                 ; cpu (-1 = any CPU)
    mov r10, -1                 ; group_fd (-1 = no group)
    mov r8, 0                   ; flags
    syscall
    ret

do_work:
    ; More intensive work to generate measurable events
    mov rcx, 100000              ; Increase iterations
    
work_loop:
    push rcx
    
    ; Allocate memory on stack to cause page activity
    sub rsp, 4096               ; Allocate 4KB on stack
    mov rdi, rsp
    mov rax, rcx                ; Write data to potentially cause page faults
    mov [rdi], rax
    mov [rdi + 1000], rax
    mov [rdi + 2000], rax
    mov [rdi + 3000], rax
    add rsp, 4096               ; Restore stack
    
    ; Do some computation
    mov rax, rcx
    mul rax                     ; rax = rcx^2
    add rax, rcx
    
    ; Occasional write to stdout (every 10000 iterations)
    mov rax, rcx
    mov rdx, 0
    mov rbx, 10000
    div rbx
    cmp rdx, 0
    jne skip_write
    
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, dot_char
    mov rdx, 1
    syscall
    
skip_write:
    pop rcx
    loop work_loop
    
    ; Print newline
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    ret

read_counters:
    ; Read page faults counter
    mov rax, SYS_READ
    mov rdi, [page_faults_fd]
    mov rsi, page_faults_count
    mov rdx, 8
    syscall
    
    ; Read context switches counter  
    mov rax, SYS_READ
    mov rdi, [context_switches_fd]
    mov rsi, context_switches_count
    mov rdx, 8
    syscall
    ret

print_results:
    ; Print page faults
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, page_faults_msg
    mov rdx, page_faults_msg_len
    syscall
    
    mov rax, [page_faults_count]
    call print_number
    call print_newline
    
    ; Print context switches
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, context_switches_msg
    mov rdx, context_switches_msg_len
    syscall
    
    mov rax, [context_switches_count]
    call print_number
    call print_newline
    ret

print_number:
    ; Convert number in RAX to string and print it
    mov rdi, number_buffer + 19  ; Point to end of buffer
    mov byte [rdi], 0           ; Null terminator
    mov rbx, 10                 ; Divisor
    
convert_loop:
    dec rdi
    xor rdx, rdx
    div rbx                     ; RAX = RAX / 10, RDX = RAX % 10
    add dl, '0'                 ; Convert digit to ASCII
    mov [rdi], dl
    test rax, rax
    jnz convert_loop
    
    ; Calculate length
    mov rax, number_buffer + 19
    sub rax, rdi
    mov rdx, rax                ; Length
    
    ; Print the number
    mov rax, SYS_WRITE
    mov rsi, rdi                ; String start
    mov rdi, 1                  ; stdout
    syscall
    ret

print_newline:
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    ret

perf_error:
    ; Print error message with errno
    mov [errno_value], rax      ; Save the negative errno
    neg rax                     ; Make it positive
    mov [errno_value], rax
    
    mov rax, SYS_WRITE
    mov rdi, 2                  ; stderr
    mov rsi, error_msg
    mov rdx, error_len
    syscall
    
    ; Print errno value
    mov rax, [errno_value]
    call print_number_stderr
    
    mov rax, SYS_WRITE
    mov rdi, 2
    mov rsi, newline
    mov rdx, 1
    syscall
    
    mov rax, SYS_EXIT
    mov rdi, 1                  ; Exit with error
    syscall

print_number_stderr:
    ; Convert number in RAX to string and print to stderr
    mov rdi, number_buffer + 19  ; Point to end of buffer
    mov byte [rdi], 0           ; Null terminator
    mov rbx, 10                 ; Divisor
    
convert_loop_stderr:
    dec rdi
    xor rdx, rdx
    div rbx                     ; RAX = RAX / 10, RDX = RAX % 10
    add dl, '0'                 ; Convert digit to ASCII
    mov [rdi], dl
    test rax, rax
    jnz convert_loop_stderr
    
    ; Calculate length
    mov rax, number_buffer + 19
    sub rax, rdi
    mov rdx, rax                ; Length
    
    ; Print the number to stderr
    mov rax, SYS_WRITE
    mov rsi, rdi                ; String start
    mov rdi, 2                  ; stderr
    syscall
    ret

segment readable writable

; Performance event file descriptors
page_faults_fd dq 0
context_switches_fd dq 0

; Performance counters
page_faults_count dq 0
context_switches_count dq 0

; Error handling
errno_value dq 0

; perf_event_attr structure (128 bytes)
perf_attr rb PERF_ATTR_SIZE

; Buffer for number conversion
number_buffer rb 20

; Messages
header_msg db 'Software Performance Events:', 10
header_len = $ - header_msg

page_faults_msg db 'Page Faults: '
page_faults_msg_len = $ - page_faults_msg

context_switches_msg db 'Context Switches: '
context_switches_msg_len = $ - context_switches_msg

error_msg db 'Error: Failed to open perf event, errno = '
error_len = $ - error_msg

dot_char db '.'
newline db 10
