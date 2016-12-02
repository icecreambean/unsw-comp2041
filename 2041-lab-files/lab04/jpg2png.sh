#!/bin/sh

# note: for file in *.jpg (works much better)
# ls doesn't work but * does
for file in *
do
    # for f in "$file" (" " treats $file as one word)
    # check if file is a jpg
    echo "$file" | egrep '\.jpg$' > /dev/null
    if test $? -ne 0
    then
        continue
    fi
    name=`echo "$file" | cut -d'.' -f1`
    # check if png equivalent already exists
    if test -e "$name.png"
    then
        echo "$name.png already exists"
        exit 1
    fi
    # convert from jpg -> png
    convert "$name.jpg" "$name.png"
    if test $? -ne 0 # if convert fails
    then
        echo "[convert failed]"
        exit 1
    fi
    rm "$name.jpg"
done
