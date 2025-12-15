#!/bin/bash


function test()
{
    echo 1
    echo 2
    echo 3
    return 1
}

# fails:  $? is 0
#declare -a array
#mapfile -t array < <(test)


# fails:  $? is 0
#declare -a array=( $(test) )

# pass:  $? is 1
declare -a array
array=( $(test) )

echo $?
