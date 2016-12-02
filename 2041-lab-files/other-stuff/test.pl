#!/usr/bin/perl

use warnings;

open(F, "<", "stuff") or die "$!";
while ($lines = <F>) {
	chomp $lines;
	print($lines,"\n");
}
