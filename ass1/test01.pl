#!/usr/bin/perl -w
# put your demo script here
$ a = "ab";
$ { b } = "AB";
print "$   {  a  }\n";
print "$      b  }\n";

# tests: spacing inbetween "$" and variable name can be tolerated
# by the translator and that this is also true within strings

# tests whether you have considered the small variation "${...}" or not

# output:
#ab
#AB  }
