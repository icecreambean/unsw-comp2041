#!/bin/sh

error_mess='Usage: ./echon.sh <number of lines> <string>'
error_mess2='./echon.sh: argument 1 must be a non-negative integer'
#if test $# -ne 2
#if [ $# -ne 2 ]
#if [ $1 -lt 0 ]   # '<' doesn't work: still counts as special character

#if [ $# != 2 ] || [ $1 -lt 0 ]   # works
#if test $# -ne 2 -o $1 -lt 0   # -o means or. 0 args bug, idk how to fix.

if [ $# != 2 ]
then
	echo $error_mess
	exit 1
fi

# use regex to check ^+/-{digits}.{digits?}$ in a variable, or can use: $1 -eq $1
# trying $1 -ne $1 doesn't work: still asks for int expression expected
# [[ ]] is not compatible with sh (only with more modern versions)

# set $? (error code) flag to what we want
echo $1 | egrep '^\+?[0-9]+$' > /dev/null

if [ $? -ne 0 ] || [ $1 -lt 0 ]
then
	echo $error_mess2
	exit 1
fi

count=$1
while test $count -gt 0
do
	echo $2
	count=`expr $count - 1`
done
