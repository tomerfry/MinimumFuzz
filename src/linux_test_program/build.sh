#! /bin/sh

gcc -g -O0 -fno-stack-protector -z execstack fuzzer_test_program.c -o vulnerable_test

