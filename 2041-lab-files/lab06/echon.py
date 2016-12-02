#!/usr/bin/env python3
import sys
if len(sys.argv) != 3: # includes filename
    print("Usage: {} <number of lines> <string> at {}.".format(sys.argv[0], sys.argv[0]))
    sys.exit(1)
# up only by default
for i in range(0, int(sys.argv[1])):
    print(sys.argv[2])
