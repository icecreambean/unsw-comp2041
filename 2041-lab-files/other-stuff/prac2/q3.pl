#!/usr/bin/env perl

use warnings;

exit if scalar @ARGV == 0;

for $arg (@ARGV) {
   if (!defined $a{$arg}) {
		push @l, $arg;
	}
   $a{$arg}++;
}

$max = 0;
for $arg (@l) {
   if ($a{$arg} > $max) {
      $res = $arg;
		$max = $a{$arg};
	}
}

print $res,"\n";
