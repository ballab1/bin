#!/bin/bash


for h in s1 s3 s4 s6 s7 s8;do
    scp ~/gc.tar $h:.
    ssh $h 'cd /;sudo tar xf /home/bobb/gc.tar; rm /home/bobb/gc.tar'
done
