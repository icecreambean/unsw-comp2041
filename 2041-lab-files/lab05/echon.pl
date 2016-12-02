#!/usr/bin/perl -w
# check no. args
$error_args = "Usage: ./echon.pl <number of lines> <string>";
if (@ARGV != 2) {   # @ARGV in a scalar context
    die "$error_args";
}

# given integer n (arg0) and a string (arg1)
$n = $ARGV[0];
$line = $ARGV[1];
for ($i = 0; $i < $n; $i++) {
    print "$line\n";
}
