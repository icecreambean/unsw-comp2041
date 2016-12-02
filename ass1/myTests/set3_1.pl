#!/usr/bin/perl
#print(1 <=> 2 <=> 3); #gives syntax errors (yay!)
print("=========SET3_1=========\n");
print("1:",(1 <=> 2) <=> (3 <=> 4), "\n");

print("2:",("a" cmp "b") cmp ("c" cmp "d"),"\n");

print("3:",("a" cmp "b") <=> ("c" cmp "d"),"\n");
