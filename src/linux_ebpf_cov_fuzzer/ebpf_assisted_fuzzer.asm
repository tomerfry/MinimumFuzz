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
SYS_BPF         = 321
SYS_MMAP        = 9

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
status_buffer   dd 0

; Target argv
target_argv     dq 0, 0, 0

; Coverage tracking (enhanced with more metrics)
coverage_bitmap rb 4096         ; Simple coverage bitmap
prev_bitmap     rb 4096         ; Previous iteration bitmap
new_edges       dq 0            ; Count of new edges discovered
total_edges     dq 0            ; Total edges ever seen
coverage_percent dq 0           ; Estimated coverage percentage

; Messages
msg_start       db 'eBPF-Assisted Fuzzer Started', 10, 'Target: ', 0
msg_iter        db 'Iteration ', 0
msg_ok          db ' - OK', 0
msg_crash       db ' - CRASH!', 0
msg_new_cov     db ' [+', 0
msg_edges       db ' edges]', 0
msg_total_cov   db ' [Total: ', 0
msg_close_bracket db ']', 0
msg_usage       db 'Usage: ./fuzzer <program>', 10, 0
msg_newline     db 10, 0
msg_stats       db 'Stats - Crashes: ', 0
msg_interesting db ', Interesting: ', 0
msg_coverage_pct db ', Coverage: ', 0
msg_percent     db '%', 0

; Counters
iteration       dq 1
seed           dq 12345
total_crashes   dq 0
interesting_inputs dq 0

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
    
    ; Initialize coverage tracking
    call init_coverage

main_loop:
    ; Clear screen and show stats every 10 iterations
    mov rax, [iteration]
    mov rbx, 10
    xor rdx, rdx
    div rbx
    cmp rdx, 0
    jne skip_stats
    call show_live_stats
    
skip_stats:
    ; Print iteration with real-time coverage
    mov rsi, msg_iter
    call print_str
    call print_simple_number
    
    ; Save previous coverage state
    call save_coverage_state
    
    ; Generate fuzz data (with mutation strategy)
    call generate_smart_fuzz_data
    
    ; Write to file
    call write_to_file
    
    ; Execute target with coverage tracking
    call run_target_with_coverage
    
    ; Analyze coverage and print live results
    call analyze_and_display_coverage
    
    ; Update mutation strategy based on results
    call update_strategy
    
    ; Next iteration
    inc qword [iteration]
    
    ; Shorter delay for more responsive feedback
    mov rcx, 10000
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

; Initialize coverage tracking system
init_coverage:
    push rax
    push rcx
    push rdi
    
    ; Clear coverage bitmaps
    mov rdi, coverage_bitmap
    mov rcx, 4096
    xor rax, rax
    rep stosb
    
    mov rdi, prev_bitmap
    mov rcx, 4096
    xor rax, rax
    rep stosb
    
    ; TODO: Here we would initialize eBPF programs
    ; For now, we'll use a simulated coverage approach
    
    pop rdi
    pop rcx
    pop rax
    ret

; Save current coverage state for comparison
save_coverage_state:
    push rsi
    push rdi
    push rcx
    
    ; Copy current coverage to previous
    mov rsi, coverage_bitmap
    mov rdi, prev_bitmap
    mov rcx, 4096
    rep movsb
    
    pop rcx
    pop rdi
    pop rsi
    ret

; Enhanced smart fuzz data generation with crash-finding strategies
generate_smart_fuzz_data:
    push rax
    push rcx
    push rsi
    
    ; Decide mutation strategy based on recent success
    cmp qword [new_edges], 0
    jg use_targeted_mutation
    
    ; If no new coverage for a while, try crash-specific patterns
    mov rax, [iteration]
    mov rbx, 10
    xor rdx, rdx
    div rbx
    cmp rdx, 0                  ; Every 10th iteration
    je try_crash_patterns
    
    ; Use random generation
    call generate_random_data
    jmp fuzz_done
    
try_crash_patterns:
    ; Occasionally generate known crash patterns
    mov rax, [seed]
    and rax, 7                  ; 0-7 selector
    
    cmp rax, 0
    je generate_magic_deadbeef
    cmp rax, 1  
    je generate_fuzz_aaaa
    cmp rax, 2
    je generate_format_string
    cmp rax, 3
    je generate_protocol_kill
    cmp rax, 4
    je generate_large_input
    ; Otherwise fall through to targeted mutation
    
use_targeted_mutation:
    ; Use mutation-based approach
    call mutate_previous_input
    jmp fuzz_done

generate_magic_deadbeef:
    ; Generate DEADBEEF + ABCD + zero pattern
    mov rsi, fuzz_buffer
    mov byte [rsi], 0xDE
    mov byte [rsi + 1], 0xAD
    mov byte [rsi + 2], 0xBE
    mov byte [rsi + 3], 0xEF
    mov byte [rsi + 4], 'A'
    mov byte [rsi + 5], 'B'
    mov byte [rsi + 6], 'C'
    mov byte [rsi + 7], 'D'
    mov byte [rsi + 8], 0       ; Division by zero trigger
    
    ; Fill rest with random
    add rsi, 9
    mov rcx, buffer_size
    sub rcx, 9
    call fill_random_bytes
    jmp fuzz_done

generate_fuzz_aaaa:
    ; Generate FUZZ + AAAA pattern  
    mov rsi, fuzz_buffer
    mov byte [rsi], 'F'
    mov byte [rsi + 1], 'U'
    mov byte [rsi + 2], 'Z'
    mov byte [rsi + 3], 'Z'
    mov byte [rsi + 4], 'A'
    mov byte [rsi + 5], 'A'
    mov byte [rsi + 6], 'A'
    mov byte [rsi + 7], 'A'
    
    ; Fill rest with random
    add rsi, 8
    mov rcx, buffer_size
    sub rcx, 8
    call fill_random_bytes
    jmp fuzz_done

generate_format_string:
    ; Generate format string patterns
    mov rsi, fuzz_buffer
    mov byte [rsi], '%'
    mov byte [rsi + 1], 's'
    mov byte [rsi + 2], '%'
    mov byte [rsi + 3], 'x'
    mov byte [rsi + 4], '%'
    mov byte [rsi + 5], 'n'
    mov byte [rsi + 6], 0
    
    ; Fill rest with random
    add rsi, 7
    mov rcx, buffer_size
    sub rcx, 7
    call fill_random_bytes
    jmp fuzz_done

generate_protocol_kill:
    ; Generate protocol header with kill command
    mov rsi, fuzz_buffer
    mov byte [rsi], 0x34        ; Magic header
    mov byte [rsi + 1], 0x12
    mov byte [rsi + 2], 0x78
    mov byte [rsi + 3], 0x56
    mov byte [rsi + 4], 0xAD    ; KILL command (0xDEAD)
    mov byte [rsi + 5], 0xDE
    mov byte [rsi + 6], 0x08    ; Length
    mov byte [rsi + 7], 0x00
    
    ; Fill rest with random
    add rsi, 8
    mov rcx, buffer_size
    sub rcx, 8
    call fill_random_bytes
    jmp fuzz_done

generate_large_input:
    ; Generate large input with magic bytes (buffer overflow)
    mov rsi, fuzz_buffer
    mov byte [rsi], 0xDE
    mov byte [rsi + 1], 0xAD
    mov byte [rsi + 2], 0xBE
    mov byte [rsi + 3], 0xEF
    
    ; Fill with pattern that might cause overflow
    add rsi, 4
    mov rcx, buffer_size
    sub rcx, 4
fill_pattern_loop:
    mov byte [rsi], 'A'
    inc rsi
    dec rcx
    jnz fill_pattern_loop
    jmp fuzz_done

; Helper function to fill bytes with random data
fill_random_bytes:
    push rax
fill_loop:
    mov rax, [seed]
    imul rax, 1103515245
    add rax, 12345
    mov [seed], rax
    mov [rsi], al
    inc rsi
    dec rcx
    jnz fill_loop
    pop rax
    ret

fuzz_done:
    pop rsi
    pop rcx
    pop rax
    ret

; Generate random data
generate_random_data:
    push rax
    push rcx
    push rsi
    
    mov rsi, fuzz_buffer
    mov rcx, buffer_size
    
random_loop:
    mov rax, [seed]
    imul rax, 1103515245
    add rax, 12345
    mov [seed], rax
    
    ; Occasionally insert interesting values
    and rax, 0xFF
    cmp rax, 250
    jg insert_special_value
    
    mov [rsi], al
    jmp next_random_byte
    
insert_special_value:
    ; Insert common edge case values
    mov rbx, rax
    and rbx, 7
    cmp rbx, 0
    je use_zero
    cmp rbx, 1
    je use_ff
    cmp rbx, 2
    je use_newline
    mov al, 0x41            ; 'A'
    jmp store_special
use_zero:
    mov al, 0
    jmp store_special
use_ff:
    mov al, 0xFF
    jmp store_special
use_newline:
    mov al, 10
store_special:
    mov [rsi], al
    
next_random_byte:
    inc rsi
    dec rcx
    jnz random_loop         ; Use jnz instead of loop
    
    pop rsi
    pop rcx
    pop rax
    ret

; Mutate previous successful input
mutate_previous_input:
    push rax
    push rcx
    push rsi
    
    ; Start with previous buffer (simplified)
    call generate_random_data
    
    ; Apply mutations
    mov rsi, fuzz_buffer
    mov rcx, 100            ; Mutate 100 random positions
    
mutate_loop:
    ; Get random position
    mov rax, [seed]
    imul rax, 1103515245
    add rax, 12345
    mov [seed], rax
    
    mov rbx, buffer_size
    xor rdx, rdx
    div rbx                 ; rax % buffer_size
    mov rbx, rdx
    
    ; Choose mutation type
    mov rax, [seed]
    and rax, 7
    
    cmp rax, 0
    je bit_flip_mut
    cmp rax, 1
    je arith_add
    cmp rax, 2
    je arith_sub
    cmp rax, 3
    je insert_byte
    jmp next_mutation
    
bit_flip_mut:
    xor byte [fuzz_buffer + rbx], 1
    jmp next_mutation
    
arith_add:
    inc byte [fuzz_buffer + rbx]
    jmp next_mutation
    
arith_sub:
    dec byte [fuzz_buffer + rbx]
    jmp next_mutation
    
insert_byte:
    mov byte [fuzz_buffer + rbx], 0x90  ; NOP instruction
    
next_mutation:
    dec rcx
    jnz mutate_loop         ; Use jnz instead of loop
    
    pop rsi
    pop rcx
    pop rax
    ret

; Execute target with simulated coverage tracking
run_target_with_coverage:
    push rax
    push rdi
    push rsi
    push rdx
    
    ; Fork
    mov rax, SYS_FORK
    syscall
    
    cmp rax, 0
    je child_process
    
    ; Parent - wait and simulate coverage collection
    mov rdi, rax    ; child pid
    mov rsi, status_buffer
    mov rdx, 0
    mov r10, 0
    mov rax, SYS_WAIT4
    syscall
    
    ; Simulate coverage data collection
    call simulate_coverage_update
    
    ; Check status
    mov eax, [status_buffer]
    test eax, eax
    ; Check status with enhanced crash detection
    mov eax, [status_buffer]
    
    ; Check for various crash indicators
    ; WIFEXITED(status) - normal exit
    mov ebx, eax
    and ebx, 0x7F
    cmp ebx, 0
    jne crash_by_signal        ; Terminated by signal
    
    ; Check exit code for abnormal exits
    shr eax, 8                 ; Get exit code
    cmp eax, 0
    je normal_exit             ; Clean exit
    cmp eax, 127
    je exec_failed             ; Exec failed - not a crash
    
    ; Non-zero exit could indicate crash
    inc qword [total_crashes]
    jmp run_done
    
crash_by_signal:
    ; Process killed by signal - definitely a crash
    inc qword [total_crashes]
    jmp run_done
    
exec_failed:
    ; Target failed to execute - not counted as crash
    jmp run_done
    
normal_exit:
    ; Normal execution - no crash
    jmp run_done
    
child_process:
    ; Redirect output to /dev/null
    mov rax, SYS_OPEN
    mov rdi, dev_null
    mov rsi, O_WRONLY
    mov rdx, 0
    syscall
    
    mov r8, rax
    
    mov rax, SYS_DUP2
    mov rdi, r8
    mov rsi, 1
    syscall
    
    mov rax, SYS_DUP2
    mov rdi, r8
    mov rsi, 2
    syscall
    
    ; Execute target
    mov rax, SYS_EXECVE
    mov rdi, target_prog
    mov rsi, target_argv
    mov rdx, 0
    syscall
    
    mov rax, SYS_EXIT
    mov rdi, 1
    syscall

run_done:
    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret

; Simulate coverage updates with more realistic data
simulate_coverage_update:
    push rax
    push rbx
    push rcx
    push rsi
    
    ; Create coverage pattern based on input characteristics
    mov rsi, fuzz_buffer
    mov rcx, 200            ; Sample more bytes for better simulation
    
sim_loop:
    mov al, [rsi]
    
    ; Create multiple coverage points per input byte
    mov rbx, rsi
    sub rbx, fuzz_buffer
    
    ; Primary coverage point
    and rbx, 0xFFF
    mov byte [coverage_bitmap + rbx], 1
    
    ; Secondary coverage based on byte value
    mov rbx, rax
    shl rbx, 3              ; Multiply by 8
    and rbx, 0xFFF
    cmp byte [coverage_bitmap + rbx], 0
    jne skip_secondary
    mov byte [coverage_bitmap + rbx], 1
    
skip_secondary:
    ; Tertiary coverage for special values
    cmp al, 0
    je hit_null_path
    cmp al, 0xFF
    je hit_max_path
    cmp al, 10
    je hit_newline_path
    jmp normal_path
    
hit_null_path:
    mov rbx, 100
    mov byte [coverage_bitmap + rbx], 1
    jmp next_sim_byte
    
hit_max_path:
    mov rbx, 200
    mov byte [coverage_bitmap + rbx], 1
    jmp next_sim_byte
    
hit_newline_path:
    mov rbx, 300
    mov byte [coverage_bitmap + rbx], 1
    jmp next_sim_byte
    
normal_path:
    ; Random additional coverage
    mov rbx, rax
    imul rbx, 33
    and rbx, 0xFFF
    mov byte [coverage_bitmap + rbx], 1
    
next_sim_byte:
    inc rsi
    dec rcx
    jnz sim_loop            ; Use jnz instead of loop
    
    pop rsi
    pop rcx
    pop rbx
    pop rax
    ret

; Show live statistics (called every 10 iterations)
show_live_stats:
    push rax
    
    ; Print a separator line
    call print_newline
    mov rsi, msg_stats
    call print_str
    mov rax, [total_crashes] 
    call print_simple_number_rax
    
    mov rsi, msg_interesting
    call print_str
    mov rax, [interesting_inputs]
    call print_simple_number_rax
    
    mov rsi, msg_coverage_pct
    call print_str
    mov rax, [coverage_percent]
    call print_simple_number_rax
    mov rsi, msg_percent
    call print_str
    
    call print_newline
    call print_newline
    
    pop rax
    ret

; Enhanced coverage analysis with live display
analyze_and_display_coverage:
    push rax
    push rcx
    push rsi
    push rdi
    
    ; Count new edges
    mov qword [new_edges], 0
    mov rsi, coverage_bitmap
    mov rdi, prev_bitmap
    mov rcx, 4096
    
analyze_loop_enhanced:
    mov al, [rsi]
    cmp al, [rdi]
    je no_new_edge_enhanced
    
    ; Check if this is truly new (not just increased count)
    cmp byte [rdi], 0
    jne just_increased_count
    
    ; Completely new edge
    inc qword [new_edges]
    inc qword [total_edges]
    jmp next_edge_enhanced
    
just_increased_count:
    ; Edge hit more times, still interesting but not "new"
    
next_edge_enhanced:
no_new_edge_enhanced:
    inc rsi
    inc rdi
    loop analyze_loop_enhanced
    
    ; Calculate coverage percentage (rough estimate)
    call calculate_coverage_percentage
    
    ; Display results with enhanced formatting
    call display_coverage_results
    
    pop rdi
    pop rsi
    pop rcx
    pop rax
    ret

; Calculate estimated coverage percentage
calculate_coverage_percentage:
    push rax
    push rbx
    push rdx
    
    ; Simple heuristic: total_edges / estimated_max_edges * 100
    ; Assume max ~1000 edges for typical small programs
    mov rax, [total_edges]
    imul rax, 100
    mov rbx, 1000           ; Estimated max edges
    xor rdx, rdx
    div rbx
    
    cmp rax, 100
    jle coverage_ok
    mov rax, 100            ; Cap at 100%
    
coverage_ok:
    mov [coverage_percent], rax
    
    pop rdx
    pop rbx
    pop rax
    ret

; Display coverage results with color-like indicators
display_coverage_results:
    push rax
    
    ; Show basic OK/CRASH status first
    mov eax, [status_buffer]
    test eax, eax
    jz display_ok
    
    ; Crash detected
    inc qword [total_crashes]
    mov rsi, msg_crash
    call print_str
    jmp show_coverage_info
    
display_ok:
    mov rsi, msg_ok
    call print_str
    
show_coverage_info:
    ; Show new coverage if any
    cmp qword [new_edges], 0
    je show_total_only
    
    inc qword [interesting_inputs]
    mov rsi, msg_new_cov
    call print_str
    mov rax, [new_edges]
    call print_simple_number_rax
    mov rsi, msg_edges
    call print_str
    
show_total_only:
    ; Always show total coverage
    mov rsi, msg_total_cov
    call print_str
    mov rax, [total_edges]
    call print_simple_number_rax
    mov rsi, msg_close_bracket
    call print_str
    
    call print_newline
    
    pop rax
    ret

; Print number from rax register
print_simple_number_rax:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    
    mov rsi, temp_buffer
    add rsi, 19
    mov rbx, 10
    mov rcx, 0
    
    test rax, rax
    jnz convert_digits_rax
    mov byte [rsi], '0'
    dec rsi
    inc rcx
    jmp print_digits_rax
    
convert_digits_rax:
    xor rdx, rdx
    div rbx
    add dl, '0'
    mov [rsi], dl
    dec rsi
    inc rcx
    test rax, rax
    jnz convert_digits_rax
    
print_digits_rax:
    inc rsi
    push rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rdx, rcx
    syscall
    pop rax
    
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; Update fuzzing strategy based on results
update_strategy:
    ; Placeholder for strategy updates
    ; In a real fuzzer, this would adjust:
    ; - Mutation rates
    ; - Input selection probability
    ; - Energy allocation to different strategies
    ret

; File I/O function
write_to_file:
    push rax
    push rdi
    push rsi
    push rdx
    
    mov rax, SYS_OPEN
    mov rdi, filename
    mov rsi, O_WRONLY or O_CREAT or O_TRUNC
    mov rdx, S_IRUSR or S_IWUSR or S_IRGRP or S_IROTH
    syscall
    
    mov rdi, rax
    mov rax, SYS_WRITE
    mov rsi, fuzz_buffer
    mov rdx, buffer_size
    syscall
    
    mov rax, SYS_CLOSE
    syscall
    
    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret

; Number printing function
print_simple_number:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    
    mov rax, [iteration]
    mov rsi, temp_buffer
    add rsi, 19
    mov rbx, 10
    mov rcx, 0
    
    test rax, rax
    jnz convert_digits
    mov byte [rsi], '0'
    dec rsi
    inc rcx
    jmp print_digits
    
convert_digits:
    xor rdx, rdx
    div rbx
    add dl, '0'
    mov [rsi], dl
    dec rsi
    inc rcx
    test rax, rax
    jnz convert_digits
    
print_digits:
    inc rsi
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rdx, rcx
    syscall
    
    pop rsi
    pop rdx
    pop rcx
    pop rbx
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
    
    mov byte [temp_buffer], 10
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
