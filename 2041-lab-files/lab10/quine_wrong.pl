#!/usr/bin/perl -w
$fn = $0;
$fn = substr($0, 2) if $fn =~ /^\.\//;
print("$fn\n");
open(F, "<", $fn) or die "$!"; # not allowed to access file streams
print <F>;
