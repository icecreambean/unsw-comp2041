#!/usr/bin/perl -w

$a = 100;
print "$         a    \n";     # this still works
#print "$         ARGV   [    1    ]    \n"; # doesnt work

print "$    {     ARGV   [    1    ]    }\n";
print "aa $  ARGV[ 1 ] aa\n"; # works (so long as no space between word and "[")

print $    {     ARGV   [    1    ]    },"\n";
print  $    ARGV     [  1  ] , "\n";

print("\$20\n");

# try input: 1 2 3 4  (result always 2nd element)
