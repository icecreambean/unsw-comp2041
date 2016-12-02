#!/bin/sh

echo "$*"
echo "$@"

for i in "$@"; do
		  echo "$i"
done

for i in "$*"; do
		  echo "$i"
done
