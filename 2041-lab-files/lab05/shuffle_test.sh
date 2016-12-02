#!/bin/sh

# rationale: any answer is fine, so long as non-deterministic
# and, no line in one file that doesn't exist in another file

i=0;
consec=(`seq 20`)   # brackets specify 'is a bash array'
#echo ${consec[*]}   # (* or @) works, but only with echo (not with printf)
#IFS="\n"   # array element depends on IFS
rand_1=(`echo "${consec[@]}" | tr ' ' '\n' | ./shuffle.pl`)
sleep 0.1 # to ensure seed changed (in seconds)
rand_2=(`echo "${consec[@]}" | tr ' ' '\n' | ./shuffle.pl`)
# some tests to trigger errors (non-matching elements)
#consec[0]=2;
#rand_1[0]=1;

#unset IFS
# debugging printfs
#echo ${rand_1[$@]}
#echo ${rand_2[$@]}

# quick check: num lines the same
if [ ${#rand_1[@]} -ne ${#consec[@]} ]
then
    echo "$0 failed (0): rand_1 and consec not same size"
    exit 1
fi
# more precise: check same elements in sets
i=0
while [ $i -lt ${#rand_1[@]} ]
do
    j=0
    count=0
    while [ $j -lt ${#consec[@]} ]
    do
        if [ ${rand_1[$i]} -eq ${consec[$j]} ]
        then
            (( ++count ))
        fi
        j=$(($j + 1))
    done
    if [ "$count" -ne 1 ]
    then
        echo "$0 failed (1): rand_1 not agreeing with consec"
        echo "   at index $i in rand_1: '${rand_1[$i]}'"
        echo "   occurrences in consec: $count"
        echo "   rand_1: '${rand_1[@]}'"
        echo "   consec: '${consec[@]}'"
        echo "expected: occurrences == 1"
        exit 1
    fi
    i=$(($i + 1))
done
# copypasta but with role reversal
i=0
while [ $i -lt ${#consec[@]} ]
do
    j=0
    count=0
    while [ $j -lt ${#rand_1[@]} ]
    do
        if [ ${consec[$i]} -eq ${rand_1[$j]} ]
        then
            (( ++count ))
        fi
        j=$(($j + 1))
    done
    if [ "$count" -ne 1 ]
    then
        echo "$0 failed (2): consec not agreeing with rand_1"
        echo "   at index $i in consec: '${consec[$i]}'"
        echo "   occurrences in rand_1: $count"
        echo "   consec: '${consec[@]}'"
        echo "   rand_1: '${rand_1[@]}'"
        echo "expected: occurrences == 1"
        exit 1
    fi
    i=$(($i + 1))
done

# check non-deterministic in order
i=0
diff=1  # assume false
# error triggering tests
#rand_2=(${rand_1[@]})
while [ $i -lt ${#rand_1[@]} ]
do
    if [ ${rand_1[$i]} -ne ${rand_2[$i]} ]
    then
        diff=0
        break
    fi
    (( ++i ))
done
if [ $diff -eq 1 ]
then
    echo "$0 failed (3): program does not randomise"
    echo "   rand_1: ${rand_1[@]}"
    echo "   rand_2: ${rand_2[@]}"
    echo "expected: different lists"
    exit 1
fi

echo "$0: all tests successful."
echo "   consec: ${consec[@]}"
echo "   rand_1: ${rand_1[@]}"
echo "   rand_2: ${rand_2[@]}"


<<"COMMENT_1"
# old code, doesn't work because forgot '$' in test
for val in ${rand_1[@]}
do
    # remove added newline
    val=`echo "$val" | tr -d '\n'`
    count=0
    for consec_val in ${consec[@]}
    do
        printf "!$val!$consec_val!\n"
        # doesn't work because forgot dollar signs
        if test val = consec_val
        then
            (( ++count ))
        fi
    done
    echo $count
done
COMMENT_1
