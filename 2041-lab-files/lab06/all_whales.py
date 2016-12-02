#!/usr/bin/env python3
import sys, re

all_whales = {}
for line in sys.stdin: # best method
    line = line.strip().lower()
    line = re.sub('s$', '', line)
    line = re.sub('\s+', ' ', line)
    n_whales, whale_type = line.split(' ', 1)
    # 1: means, num splits to be made
    n_whales = int(n_whales)
    if whale_type not in all_whales.keys():
        all_whales[whale_type] = [0,0]
    # a[0]: pods, a[1]: total
    all_whales[whale_type][0] += 1
    all_whales[whale_type][1] += n_whales

all_whale_keys = list(all_whales.keys())
all_whale_keys.sort()
for whale_type in all_whale_keys:
    print(whale_type, "observations:",
        all_whales[whale_type][0], "pods,",
        all_whales[whale_type][1], "individuals")
