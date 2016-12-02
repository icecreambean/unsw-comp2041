#!/usr/bin/env python3
import sys, re
for line in sys.stdin:  # .readlines() unnecessary
    line = line.rstrip('\n')
    line = re.sub(r'[0-4]', r'<', line)
    line = re.sub(r'[6-9]', r'>', line)
    print(line) # re.subn

# without compile, call static function re.method()
# compile regex objects, then can do: name.method()
