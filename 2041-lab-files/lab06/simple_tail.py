#!/usr/bin/env python3
# spec:
#   no command line options, or error handling
#   no need to read from stdin
# spec: just print last n lines of each file
import sys
n = 10
# ignore the .py filename
for filename in sys.argv[1:]:
    f_handle = open(filename)
    f_contents = f_handle.readlines()
    for line in f_contents[len(f_contents)-n:]:
        print(line, end="")
    f_handle.close()
