#!/bin/sh
if [ $# != 1 ] || [ `echo -n "$1" | wc -m | sed  's/ //g'` != 4 ]
then
    echo 'Usage: ./courses.sh <4 letter capitalised course code>'
    exit 1
fi

start_letter=`echo $1 | cut -c1`
ug_website='http://www.handbook.unsw.edu.au/vbook2016/brCoursesByAtoZ.jsp?StudyLevel=Undergraduate&descr='
pg_website='http://www.handbook.unsw.edu.au/vbook2016/brCoursesByAtoZ.jsp?StudyLevel=Postgraduate&descr='

# the cutting is a bit hacky?
# $( ) a cleaner alternative to backquotes

# IFS: field terminator (not separator)
# http://stackoverflow.com/questions/4128235/what-is-the-exact-meaning-of-ifs-n
# I can't get IFS to work

#old_IFS=$IFS   # can't get it to work
#IFS=$'\n'
wget -q -O- "$ug_website$start_letter" | egrep "$1"'[0-9]{4}\.html">' | \
sed 's-^.*2016/--' | sed 's/\.html">/ /g' | sed 's/\s*<\/A><\/TD>//g' \
> courses_temp_file_ug
#IFS=$old_IFS

# cut -d'/' -f7 # doesn't work for names with "/" inside them

# now do the postgraduates
wget -q -O- "$pg_website$start_letter" | egrep "$1"'[0-9]{4}\.html">' | \
sed 's-^.*2016/--' | sed 's/\.html">/ /g' | sed 's/\s*<\/A><\/TD>//g' \
> courses_temp_file_pg

cat courses_temp_file_ug courses_temp_file_pg | sort | uniq

rm courses_temp_file_ug courses_temp_file_pg
