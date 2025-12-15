#!/bin/bash

for i in {0..9};do
    printf '%d:  \e[3%dm  3%d3%d3%d  \e[9%dm 9%d9%d9%d \e[0m\n' $i $i $i $i $i $i $i $i $i
done