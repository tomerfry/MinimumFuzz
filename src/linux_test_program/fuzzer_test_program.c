#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>

// Test program with multiple code paths and vulnerabilities
// This program is designed to test fuzzer effectiveness

void vulnerable_function(char *input, size_t len) {
    char buffer[64];
    
    // Path 1: Normal case
    if (len == 0) {
        printf("Empty input\n");
        return;
    }
    
    // Path 2: Small input
    if (len < 10) {
        strncpy(buffer, input, len);
        buffer[len] = '\0';
        printf("Small input: %s\n", buffer);
        return;
    }
    
    // Path 3: Check for magic bytes
    if (input[0] == 0xDE && input[1] == 0xAD) {
        printf("Found magic bytes!\n");
        
        // Path 3a: Check for more magic
        if (len > 4 && input[2] == 0xBE && input[3] == 0xEF) {
            printf("Full magic sequence found!\n");
            
            // Path 3a1: Potential buffer overflow
            if (len > 100) {
                printf("Large input with magic!\n");
                // VULNERABILITY: Buffer overflow
                strcpy(buffer, input);  // Dangerous!
                printf("Copied: %s\n", buffer);
            }
            
            // Path 3a2: Check specific byte patterns
            if (len > 8) {
                if (input[4] == 'A' && input[5] == 'B' && 
                    input[6] == 'C' && input[7] == 'D') {
                    printf("Pattern ABCD found after magic!\n");
                    
                    // VULNERABILITY: Division by zero
                    if (input[8] == 0) {
                        int x = 42 / input[8];  // Crash!
                        printf("Result: %d\n", x);
                    }
                }
            }
        }
    }
    
    // Path 4: Check for format string patterns
    if (len > 2 && input[0] == '%' && input[1] == 's') {
        printf("Format string detected!\n");
        // VULNERABILITY: Format string bug
        printf(input);  // Dangerous!
        printf("\n");
    }
    
    // Path 5: Integer overflow checks
    if (len > 10) {
        int sum = 0;
        for (int i = 0; i < len && i < 1000; i++) {
            sum += (unsigned char)input[i];
            
            // Path 5a: Specific sum triggers
            if (sum == 1337) {
                printf("Leet sum achieved!\n");
                
                // Path 5a1: Array bounds check
                if (i > 50) {
                    // VULNERABILITY: Array out of bounds
                    char local_array[50];
                    local_array[i] = 'X';  // Potential overflow
                    printf("Array access at index %d\n", i);
                }
            }
            
            // Path 5b: Overflow condition
            if (sum > 0x7FFFFFFF) {
                printf("Integer overflow territory!\n");
                break;
            }
        }
    }
    
    // Path 6: Check for specific patterns
    if (len >= 16) {
        // Look for "FUZZ" pattern
        for (int i = 0; i <= len - 4; i++) {
            if (memcmp(&input[i], "FUZZ", 4) == 0) {
                printf("FUZZ pattern found at offset %d!\n", i);
                
                // Path 6a: Check what follows FUZZ
                if (i + 8 < len) {
                    uint32_t *value = (uint32_t*)&input[i + 4];
                    
                    // Path 6a1: Specific value triggers crash
                    if (*value == 0x41414141) {  // "AAAA"
                        printf("Critical value found!\n");
                        // VULNERABILITY: Null pointer dereference
                        char *null_ptr = NULL;
                        *null_ptr = 'X';  // Crash!
                    }
                    
                    // Path 6a2: Another specific value
                    if (*value == 0x42424242) {  // "BBBB"
                        printf("Alternative critical value!\n");
                        // VULNERABILITY: Stack overflow via recursion
                        vulnerable_function(input, len);  // Infinite recursion
                    }
                }
                break;
            }
        }
    }
    
    // Path 7: File operations based on input
    if (len > 20 && strncmp(input, "FILE:", 5) == 0) {
        printf("File operation requested!\n");
        
        // Extract filename (dangerous!)
        char filename[256];
        strncpy(filename, input + 5, len - 5);
        filename[len - 5] = '\0';
        
        // Path 7a: Try to read the file
        FILE *fp = fopen(filename, "r");
        if (fp) {
            printf("Successfully opened file: %s\n", filename);
            char file_buffer[1024];
            
            // Path 7a1: Read and process file content
            if (fgets(file_buffer, sizeof(file_buffer), fp)) {
                printf("File content: %.100s\n", file_buffer);
                
                // Path 7a1a: Check for specific content
                if (strstr(file_buffer, "SECRET")) {
                    printf("Secret found in file!\n");
                    // VULNERABILITY: Use after free simulation
                    free(file_buffer);  // This will crash since it's stack allocated
                }
            }
            fclose(fp);
        }
    }
    
    // Path 8: Network-like protocol simulation
    if (len >= 8) {
        uint16_t *header = (uint16_t*)input;
        
        // Check for protocol magic
        if (header[0] == 0x1234 && header[1] == 0x5678) {
            printf("Protocol header detected!\n");
            
            uint16_t command = header[2];
            uint16_t length = header[3];
            
            // Path 8a: Different commands
            switch (command) {
                case 0x0001:
                    printf("PING command\n");
                    break;
                    
                case 0x0002:
                    printf("DATA command\n");
                    
                    // Path 8a1: Process data based on length
                    if (length > len - 8) {
                        printf("Invalid length field!\n");
                        // VULNERABILITY: Read past buffer
                        char *data = (char*)&header[4];
                        for (int i = 0; i < length; i++) {
                            printf("%02x ", (unsigned char)data[i]);
                        }
                        printf("\n");
                    }
                    break;
                    
                case 0x0003:
                    printf("QUIT command\n");
                    exit(0);  // Normal exit
                    break;
                    
                case 0xDEAD:
                    printf("KILL command - triggering crash!\n");
                    // VULNERABILITY: Intentional crash
                    raise(SIGSEGV);
                    break;
                    
                default:
                    printf("Unknown command: 0x%04x\n", command);
                    break;
            }
        }
    }
    
    // Path 9: Mathematical operations
    if (len >= 12) {
        uint32_t *numbers = (uint32_t*)input;
        uint32_t a = numbers[0];
        uint32_t b = numbers[1];
        uint32_t c = numbers[2];
        
        // Path 9a: Check for mathematical relationships
        if (a + b == c) {
            printf("Found sum relationship: %u + %u = %u\n", a, b, c);
            
            // Path 9a1: Check for specific sums
            if (c == 0xFFFFFFFF) {
                printf("Maximum sum reached!\n");
                // VULNERABILITY: Integer overflow in calculation
                uint32_t result = a * b * c;  // Likely to overflow
                printf("Product: %u\n", result);
            }
        }
        
        // Path 9b: Division operations
        if (b != 0 && a % b == 0) {
            printf("Clean division: %u / %u = %u\n", a, b, a / b);
            
            // Path 9b1: Look for perfect squares
            uint32_t sqrt_a = 1;
            while (sqrt_a * sqrt_a < a && sqrt_a < 65536) sqrt_a++;
            
            if (sqrt_a * sqrt_a == a) {
                printf("Perfect square found: %u = %u²\n", a, sqrt_a);
            }
        }
    }
    
    // Path 10: Final sanity check
    printf("Processed %zu bytes successfully\n", len);
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        printf("Usage: %s <input_file>\n", argv[0]);
        printf("This program tests various code paths for fuzzing\n");
        return 1;
    }
    
    // Read input file
    FILE *fp = fopen(argv[1], "rb");
    if (!fp) {
        perror("fopen");
        return 1;
    }
    
    // Get file size
    fseek(fp, 0, SEEK_END);
    long file_size = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    
    if (file_size < 0 || file_size > 10000) {
        printf("Invalid file size: %ld\n", file_size);
        fclose(fp);
        return 1;
    }
    
    // Read file content
    char *buffer = malloc(file_size + 1);
    if (!buffer) {
        perror("malloc");
        fclose(fp);
        return 1;
    }
    
    size_t bytes_read = fread(buffer, 1, file_size, fp);
    fclose(fp);
    
    printf("=== Fuzzer Test Program ===\n");
    printf("Processing %zu bytes of input\n", bytes_read);
    
    // Process the input through our vulnerable function
    vulnerable_function(buffer, bytes_read);
    
    free(buffer);
    
    printf("=== Test completed successfully ===\n");
    return 0;
}
