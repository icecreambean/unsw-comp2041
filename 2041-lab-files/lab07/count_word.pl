#!/usr/bin/perl -w

die "Usage: <word>" if @ARGV != 1;
$word = lc $ARGV[0];
while ($line = <STDIN>) {
    # split by 'word'
    @remaining = split /\b$word\b/i, $line;
    $count += scalar @remaining -1;
}
print "$word occurred $count times\n"
