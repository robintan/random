#!/bin/bash

icc -openmp -O3 -std=c99 -o APSPtest APSPtest.c MatUtil.c
for n in 10, 50, 100, 200, 500, 1200, 2400, 4800
do
	echo "========================= N = $n ========================="
	for (( p = 2; p <= 10; p+=2 ))
	do
		echo "     ==================== P = $p ====================     "
		export OMP_NUM_THREADS=$p
		./APSPtest $n 1
	done
done
