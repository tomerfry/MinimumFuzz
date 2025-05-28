#! /bin/sh

rm ./ebpf_assisted_fuzzer
fasm ./ebpf_assisted_fuzzer.asm
chmod +x ./ebpf_assisted_fuzzer
