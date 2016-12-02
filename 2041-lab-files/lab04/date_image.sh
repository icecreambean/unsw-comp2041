#!/bin/sh

for file in "$@"
do
    # check img file (jpg,png, etc.)
    echo "$file" | egrep '\.(jpg|png)$' > /tmp/null
    if test $? -ne 0
    then
        continue
    fi
    # could sed it with an 'anchor' of a non-space character on each side of the regex
    timestamp=`ls -l "$file" | tr -s ' ' ' ' | cut -d' ' -f6-8`
    filename=`echo "$file" | cut -d'.' -f1`
    file_extension=`echo "$file" | cut -d'.' -f2`
    file_extension=".""$file_extension" # reattach the dot
    # convert file
    temp_file_name=date_image_temp_"$$"_"$filename"_"$file_extension"
    convert -gravity south -pointsize 36 -draw "text 0,10 '$timestamp'" "$file" "$temp_file_name"
     # if convert fails
    if test $? -ne 0
    then
        echo "[convert failed]"
        exit 1
    fi
    # cleanup
    mv "$temp_file_name" "$file"
    # Challenge: preserve modification time (using stored timestamp data)
    # Linux format: (month (as word), day, hour, min)
    MM=`echo "$timestamp" | cut -d' ' -f1`
    DD=`echo "$timestamp" | cut -d' ' -f2`
    hh=`echo "$timestamp" | cut -d' ' -f3 | cut -d':' -f1`
    mm=`echo "$timestamp" | cut -d' ' -f3 | cut -d':' -f2`
    # convert month MM to numeric value
    case "$MM" in
        Jan) MM=01 ;;
        Feb) MM=02 ;;
        Mar) MM=03 ;;
        Apr) MM=04 ;;
        May) MM=05 ;;
        Jun) MM=06 ;;
        Jul) MM=07 ;;
        Aug) MM=08 ;;
        Sep) MM=09 ;;
        Oct) MM=10 ;;
        Nov) MM=11 ;;
        Dec) MM=12 ;;
    esac
    # format day, hour, min as correct num char
    if test ${#DD} -eq 1
    then
        DD=0"$DD"
    fi
    if test ${#hh} -eq 1
    then
        hh=0"$hh"
    fi
    if test ${#mm} -eq 1
    then
        mm=0"$mm"
    fi
    touch -t "$MM$DD$hh$mm" "$file"
done
