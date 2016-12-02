#!/usr/bin/perl -w
# put your demo script here
$a = 4;
$a = $a++;
print($a,"\n");

# python doesn't have the functionality to handle this unless you
# can somehow read this and break it up onto separate lines
# (which i can't do under my current implementation unfortunately)

# this is a very context driven feature: prefix and postfix would result in
# very different results in code structure
