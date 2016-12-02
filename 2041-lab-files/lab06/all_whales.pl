#!/usr/bin/perl -w

# read from stdin
my %whale_pods;
while ($line = <STDIN>) {
    chomp $line;
    ($num, $type) = split(/ /, $line, 2);
    # 2. convert to lowercase
    #   transliterate (same as y///), doesn't require suffix g
    $type =~ tr/[A-Z]/[a-z]/;
    # 3. deleting plurality (assume naive case is safe)
    $type =~ s/s$//;
    # 4. trim leading and trailing whitespace
    $type =~ s/^\s+//;
    $type =~ s/\s+$//;  # greedy by default
    # 4. reconvert whitespace inbetween
    $type =~ s/\s+/ /g;

    $whale_pods{$type}{"n_pods"} += 1;
    $whale_pods{$type}{"total"} += $num;
}

# 1. print in alphabetical order
foreach $key (sort keys %whale_pods) {
    $n_pods = $whale_pods{"$key"}{"n_pods"};
    $total = $whale_pods{"$key"}{"total"};
    print "$key observations: $n_pods pods, $total individuals\n";
}

# last 2 dp: means no hard coding
