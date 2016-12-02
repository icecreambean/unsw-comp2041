#!/usr/bin/perl

# read from stdin
# either make use of two hashes, or a multi-dimensional hash
my %whale_pods;
while ($line = <STDIN>) {
    chomp $line;
    ($num, $type) = split(/ /, $line, 2);
    $whale_pods{$type}{"n_pods"} += 1;
    $whale_pods{$type}{"total"} += $num;
}
# print contents for that whale name in ARGV[0]
#   (Why are you keeping track of all them when you
#   only want a single whale???)
$key = $ARGV[0];
# if key doesn't exist, the values eq undef
if (defined $whale_pods{"$key"}) {
    $n_pods = $whale_pods{"$key"}{"n_pods"};
    $total = $whale_pods{"$key"}{"total"};
} else {
    $n_pods = 0;
    $total = 0;
}
print "$key observations: $n_pods pods, $total individuals\n";


# just prints out everything
<<"COMMENT"
foreach $key (keys %whale_pods) {
    $n_pods = $whale_pods{"$key"}{"n_pods"};
    $total = $whale_pods{"$key"}{"total"};
    print "$key observations: $n_pods pods, $total individuals\n";
}
COMMENT
