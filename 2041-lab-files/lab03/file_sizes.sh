#!/bin/sh

small_fn_count=0
med_fn_count=0
large_fn_count=0
# small < 10, medium-sized < 100, large otherwise
for file in `ls`
do
    n_words=`wc -l $file | sed 's/[^0-9]//g'`
    #| tr -d '\s'`  # to get rid of trailing newline (unncecessary)
    if [ $n_words -lt 10 ]
    then
        small_fn[$small_fn_count]=$file
        small_fn_count=`expr $small_fn_count + 1`
    elif [ $n_words -lt 100 ]
    then
        med_fn[$med_fn_count]=$file
        med_fn_count=`expr $med_fn_count + 1`
    else
        large_fn[$large_fn_count]=$file
        large_fn_count=`expr $large_fn_count + 1`
    fi
done

# using printf produces no \n at the end
echo 'Small files:' ${small_fn[@]}
echo 'Medium-sized files:' ${med_fn[@]}
echo 'Large files:' ${large_fn[@]}
