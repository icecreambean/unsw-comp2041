#!/usr/bin/perl -w
# put your demo script here

# print contents of a list in reverse order with a dash after
# each letter

@a = split(" ", "a b c d e f");
for ($i = $#a; $i >= 0; $i--) {
    print($a[$i],"-");
}
print("\n");
