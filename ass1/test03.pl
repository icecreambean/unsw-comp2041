#!/usr/bin/perl -w
# put your demo script here
print(1 .. 4.6);
print("a".."~");

# [1st line]: could resolve by forcing to int()
# [2nd line]: consideration: range() alone can't handle this
# could possibly do it using python's string.ascii_letters and lots
# of hardcoding towards what printable characters work and what don't in perl

# in addition, you can see ".." used as a "flip-flop" operator, which
# to my awareness is sort of like a ternary operator
