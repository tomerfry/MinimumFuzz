#! /bin/sh

rm ./simplest_perf
fasm ./simplest_perf.asm
chmod +x ./simplest_perf
sudo sysctl kernel.perf_event_paranoid=1
