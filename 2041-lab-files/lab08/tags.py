#!/usr/bin/env python3
#import subprocess
import urllib.request, operator;
import sys, re     # from... import... loses the namespace?
f_flag = False
if (sys.argv[1] == '-f'):
    f_flag = True
    sys.argv.pop(1) # pop off the flag
link = sys.argv[1]

# grab tags (need 'no check cert' for my pc...)
#html = subprocess.check_output(['wget', '-q', '-O-', '--no-check-certificate', link], universal_newlines=True)     # doesn't work very well with newlines?
html_handle = urllib.request.urlopen(link)
html_array = html_handle.readlines()
html_handle.close()
# need to convert elements from bytes to strings
for i in range(len(html_array)):    # should map it instead
    html_array[i] = str(html_array[i], 'utf-8')
html = ''.join(html_array)
html = html.replace('\n','')
# strip comments BEFORE regexing
#print(html)
#exit(1)
html = re.sub(r'<!--.*?-->', '', html)
# doesn't handle the // comments

tags = re.findall(r'<\s*?(\w+)', html)
# build dict to count freq
tags_freq = {}
tags_in_order = []
for label in tags:
    label = label.lower();
    if (label not in tags_freq):
        tags_in_order.append(label)
        tags_freq[label] = 0
    tags_freq[label] += 1
# output
if (not f_flag):
    for label in sorted(tags_freq.keys()):
        print(label, tags_freq[label])
else:
    # key=(give the function)
    # this order also not correct
    for label in sorted(tags_freq, key=tags_freq.get):
        print(label, tags_freq[label])

    # (commented out) below method in incorrect order
    #for label_tuple in sorted(tags_freq.items(), key=operator.itemgetter(1)):
    #    print (label_tuple[0], label_tuple[1])

    # pull out set of unique frequencies (also the wrong order)
    #freq_set = set(tags_freq.values())
    #for i in sorted(freq_set):
    #    for label in tags_in_order:
    #        if tags_freq[label] == i:
    #            print(label, tags_freq[label])



# NOTES:
# bash command broken up by word
# html is stored as one string; universal_newlines removes textual '\n', etc.

# NOT SECURE:
#html = re.sub(r'//.*?', '', html, 0, re.MULTILINE)
