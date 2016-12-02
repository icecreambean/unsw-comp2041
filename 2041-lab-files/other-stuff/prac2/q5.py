#!/usr/bin/env python3.5

import os

#print(open('/etc/timezone','r').readlines())
print(open('/Users/VictorTse/Desktop/test.c','r').read())

# this one seems easier in perl?
#os.system('echo how') # assume after linux filter, newline

# use .read() to read as one string

# use this instead
s = os.popen('echo how').read()
print(s)
