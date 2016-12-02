#!/usr/bin/perl -w
die "Usage: ./courses.pl <prefix>" if scalar @ARGV != 1;
open(F, "wget -q -O- http://timetable.unsw.edu.au/2016/${ARGV[0]}KENS.html | ") or die "$!";
while ($line = <F>) {
    # matching regex (more general than grep?)
    if ($line =~ /<td class.*>([A-Z]{4}\d{4})<\/a><\/td>/) {
        print "$1\n";
    }
}

#<td class="data"><a href="VISN1101.html">VISN1101</a></td>
