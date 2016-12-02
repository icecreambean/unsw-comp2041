#!/usr/bin/perl
print("=========SET2_5=========\n");
# grouping with set 2 stuff
print((3|5) & 2,"\n");

print((3||5) && (2 ** (3+4)),"\n");

print(2 + 3 <=> 5,"\n"); # 0

print(3 + (2+4) <=> 5,"\n"); # 1

print(2 + (1 <=> 4) + (6 + (23 * 19 / 2) <=> (500 ** 2)),"\n"); # 0

# (take care with <=>, check its spacing)
print((1+2<=>3*4)<=>(60/2 <=> 5*6),"\n"); # -1

print((1+2<=>3*4)+(2/2<=>5*6),"\n"); # -2
