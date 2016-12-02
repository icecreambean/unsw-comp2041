#!/usr/bin/env python3.5

import sys
if len(sys.argv) == 2:
   to_read = open(sys.argv[1], 'r')
else:
   to_read = sys.stdin
#f = open(sys.argv[1], 'r')
for line in to_read:
		  line = line.rstrip()
		  #print(line[12:19])
		  #print(line[:11] + line[19:])
		  time = line[11:19].split(':')
		  tag = 'am'
		  #print(time)
		  if int(time[0]) >= 12:
					 time[0] = str(int(time[0]) - 12)
					 if len(time[0]) == 1:
								time[0] = '0' + time[0]
					 tag = 'pm'
		  if int(time[0]) == 0:
					 time[0] = '12'
		  #print(time)
		  time = ':'.join(time) + tag
		  print(line[:11] + time + line[19:])

