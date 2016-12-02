#!/bin/sh

# args: list of directories

# extract metadata
# (title, artist, track, album, year)
# album, year: in last directory name
# title, artist, track: in file name
# don't alter (genre, comment)

for dir_path in "$@"
do
    # if path ends on a slash, remove 1 slash (temporary)
    dir_path=`echo "$dir_path" | sed 's-/$--'`
    # could also do it with cut and rev
    album=`echo "$dir_path" | sed 's-^.*/\([^/]*\)$-\1-'`
    year=`echo $album | cut -d',' -f2 | tr -d '[:space:]'`
    # multiple consecutive / don't matter unless they
    # are at the beginning of the filepath
    for file_path in "$dir_path/"*
    do
        filename=`echo "$file_path" | sed 's-^.*/\([^/]*\)$-\1-'`
        # cut doesn't work: need to look for " - " instead of just "-"
        # hence, use sed (or maybe grep). also: \s not supported in sed
        track=`echo "$filename" | \
        sed 's/^\([0-9]*\) - .*$/\1/' | tr -d '[:space:]'`
        # remainder of string beyond track
        remainder=`echo "$filename" | \
        sed 's/^[0-9]* - //'`
        # get title (in middle), remove whitespace
        title=`echo "$remainder" | sed 's/ - .*$//' | \
        sed 's/ *\([^ ].*[^ ]\) *$/\1/'`
        # get artist (at end) remove whitespace, remove '.mp3'
        artist=`echo "$remainder" | sed 's/^.* - \(.*\)$/\1/' | \
        sed 's/ *\([^ ].*[^ ]\) *$/\1/' | sed 's/\.[^.]*$//'`
        # change id3 tag
        id3 -t "$title" -a "$artist" -T "$track" -A "$album" -y "$year" "$dir_path/$filename" > /dev/null
    done
done
