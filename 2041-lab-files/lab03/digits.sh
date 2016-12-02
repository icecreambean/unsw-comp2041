#!/bin/sh

while read line
do
	# just sed each line instead of doing it manually
  echo $line | sed 's/[01234]/</g' | sed 's/[6789]/>/g'
done
