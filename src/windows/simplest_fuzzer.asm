format PE console
entry start

include 'win32a.inc'

section '.data' data readable writeable
    ; Target program to fuzz
    target_cmd      db 'notepad.exe test_input.txt', 0
    filename        db 'test_input.txt', 0
    
    ; Random seed
    seed            dd ?
    
    ; Buffer for random data
    buffer_size     = 1024
    fuzz_buffer     rb buffer_size
    
    ; File handles
    file_handle     dd ?
    bytes_written   dd ?
    
    ; Messages
    msg_start       db 'Simple Fuzzer Started', 13, 10, 0
    msg_iteration   db 'Fuzzing iteration: ', 0
    msg_newline     db 13, 10, 0
    
    ; Counter
    iteration       dd 0

section '.code' code readable executable
start:
    ; Print start message
    invoke printf, msg_start
    
    ; Initialize random seed with current time
    invoke GetTickCount
    mov [seed], eax
    
fuzzing_loop:
    ; Increment iteration counter
    inc [iteration]
    
    ; Print current iteration
    invoke printf, msg_iteration
    invoke printf, '%d', [iteration]
    invoke printf, msg_newline
    
    ; Generate random data
    call generate_random_data
    
    ; Write data to file
    call write_fuzz_data
    
    ; Execute target program
    call execute_target
    
    ; Small delay
    invoke Sleep, 100
    
    ; Check if we should continue (simple: run 10 iterations)
    cmp [iteration], 10
    jl fuzzing_loop
    
    ; Exit
    invoke ExitProcess, 0

generate_random_data:
    pushad
    
    ; Simple Linear Congruential Generator
    mov esi, fuzz_buffer
    mov ecx, buffer_size
    
random_loop:
    ; LCG: next = (a * seed + c) mod m
    mov eax, [seed]
    imul eax, 1103515245    ; multiplier
    add eax, 12345          ; increment
    mov [seed], eax
    
    ; Store random byte
    mov [esi], al
    inc esi
    loop random_loop
    
    popad
    ret

write_fuzz_data:
    pushad
    
    ; Create/open file for writing
    invoke CreateFile, filename, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
    mov [file_handle], eax
    
    cmp eax, INVALID_HANDLE_VALUE
    je write_error
    
    ; Write random data to file
    invoke WriteFile, [file_handle], fuzz_buffer, buffer_size, bytes_written, 0
    
    ; Close file
    invoke CloseHandle, [file_handle]
    
write_error:
    popad
    ret

execute_target:
    pushad
    
    ; Simple approach: use system() equivalent
    ; In a real fuzzer, you'd want more sophisticated process monitoring
    invoke WinExec, target_cmd, SW_HIDE
    
    ; Wait a bit for the process to potentially crash
    invoke Sleep, 500
    
    popad
    ret

section '.idata' import data readable writeable
    library kernel32, 'KERNEL32.DLL',\
            msvcrt, 'MSVCRT.DLL'
            
    include 'api/kernel32.inc'
    
    import msvcrt,\
           printf, 'printf'
