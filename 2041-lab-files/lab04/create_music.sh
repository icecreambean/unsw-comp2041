#!/bin/sh

# args: source mp3, dir to create test data
if test $# -ne 2
then
    echo "Usage: [source mp3] [music dir]"
    exit 1
fi
# create new music dir if dir doesn't exist
test -d "$2"
if test $? -ne 0
then
    # if not a directory, test if file exists
    if test -e "$2"
    then
        echo "Error: $2 exists but not a directory"
        exit 1
    fi
    # otherwise, make dir as not dir and doesn't exist
    #echo "Making new directory called: $2"
    mkdir "$2"
else
    echo "Writing into existing directory: $2" > /dev/null
fi

# just to save me from redownloading it every time
delete_temp=1 # false
test -e create_music_temp_file.txt
if test $? -ne 0
then
    #echo "Calling wget to extract information"
    wget -q -O- --no-check-certificate \
    'https://en.wikipedia.org/wiki/Triple_J_Hottest_100?action=raw' \
    > create_music_temp_file.txt
    delete_temp=0 # true
fi

old_IFS=$IFS
IFS=$'\n'
# while read someVar <- also works (for reading line by line)
# (no declaration of (local scope) cur_dir has occurred yet)
#test -z $cur_dir
skip_album=1 # 0 -> true
track_count=0 # 0 if initialised, count up to 10
for line in `egrep "\[\[Triple J Hottest 100|^#" create_music_temp_file.txt`
do
    # check if make new dir or make new mp3
    echo "$line" | egrep "\[\[Triple J Hottest 100" > /tmp/null
    if test $? -eq 0
    then
        # skip "of all time" albums
        echo "$line" | egrep "All [Tt]ime|[Oo]f the Past" > /tmp/null
        if test $? -eq 0
        then
            skip_album=0 # true
            continue
        fi
        # get dir name (within [[]] ), make new dir
        cur_dir=`echo "$line" | sed "s/^.*'''\[\[\(.*\)\]\]'''.*$/\1/" | \
        cut -d'|' -f1`
        #year=`echo "$cur_dir" | cut -d',' -f2 | tr -d '[:space:]'`
        skip_album=1 # skip_album = false
        track_count=0
        # create new directory if directory doesn't exist yet
        dir_path="$2"/"$cur_dir"
        if test -e "$dir_path"
        then
            # debug message turned off using /dev/null
            echo "  Directory already exists: $cur_dir" > /dev/null
        else
            mkdir "$dir_path"
        fi
        continue
    fi
    # skip track if skip album
    if test $skip_album -eq 0 # if skip_album == true
    then
        continue
    fi
    # fill in "track - title - artist.mp3", then cp source mp3 to cur_dir
    track_count=`expr $track_count + 1`
    # note: the hyphen is in Unicode?
    # account for special cases: replace / for -
    title=`echo "$line" | sed 's/^.* – \(.*\)$/\1/' | \
    sed 's/^.*|\([^|]*\)$/\1/' | tr -d '"[]' | \
    tr '/' '-'`
    # extract lhs, extract rhs of each [[]], strip leading #, [] away
    # inconsistencies with sed square brackets in character sets
    artist=`echo "$line" | sed 's/^\(.*\) – .*$/\1/' | \
    sed 's/^#//' | sed 's/\[\[[^]|]*\|\([^]]*\)\]\]/\1/g' | \
    tr -d '"[]' | sed 's/^ *\([^ ].*\)$/\1/' | tr '/' '-'`

    # sed 's/\[\[.*|\([^]]*\)\]\]/\1/g'
    # sed 's/\[\[[^|]*\|\([^]]*\)\]\]/\1/g' # almost works (issue with '|')
    # sed 's/\[\[[^]|]*\|\([^]]*\)\]\]/\1/g' # works (add ']' to not include)
    # (syntax for not including ']' is extremely sensitive)

    # probably avoid data loss by checking if the file already exists
    file_name="$track_count - $title - $artist.mp3"
    file_path="$dir_path/$file_name"
    if test -e "$file_path"
    then
        #echo "    File already exists: $file_path"
        continue
    fi
    cp "$1" "$file_path"
done
IFS=$old_IFS # default IFS is a space

# cleanup if temp files created
if test $delete_temp -eq 0
then
    rm create_music_temp_file.txt
fi
