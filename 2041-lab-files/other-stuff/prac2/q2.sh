#!/bin/sh

cat p2.txt | cut -d'|' -f2 | sort | uniq -c | sed -E 's/ +/ /g' | egrep '^ 1' | cut -d' ' -f3 | sort
