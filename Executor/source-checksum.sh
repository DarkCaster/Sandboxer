#!/bin/bash

result=0

for src in "$@"
do
 sum=`md5sum -t "$src" | cut -f1 -d' '`
 sum1=0x`echo "$sum"|cut -c1-8`
 sum2=0x`echo "$sum"|cut -c9-16`
 sum3=0x`echo "$sum"|cut -c17-24`
 sum4=0x`echo "$sum"|cut -c25-32`
 result=$((result^sum1^sum2^sum3^sum4))
done

printf "0x%x\n" "$result"
