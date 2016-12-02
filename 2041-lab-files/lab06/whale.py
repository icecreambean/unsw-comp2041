#!/usr/bin/env python3
# let's do this one smartly (only one arg allowed by spec)
import sys
# fileinput.input() works like Perl's empty <>
# Python 2: raw_input(), Python 3: input()
# sys.stdin.read() or .readlines()

# note: assignments not allowed in expressions in Python
total = 0
n_pods = 0
for line in sys.stdin: # best method
    line = line.rstrip('\n')
    n_whales, whale_type = line.split(' ', 1)
    # 1: means, num splits to be made
    n_whales = int(n_whales)
    if whale_type == sys.argv[1]:
        n_pods += 1
        total += n_whales
print(sys.argv[1], "observations:", n_pods, "pods,",
        total, "individuals")
