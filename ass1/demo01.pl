#!/usr/bin/perl -w
# put your demo script here

# a poorly made counter (5 cycles)

$counter = 0;
$remaining = 5;
$count_to = 5_000_000;
for ( ;; ) {
    print "tick!\n";
    for (;$counter < 5_000_000; $counter++) {
        # nothing to do here
    }
    print "        tock!\n";
    $counter = 0;
    while ($counter < $count_to)
    {
        $counter = $counter + 1;
    }
    $counter = 0; --$remaining;
    if ($remaining == 0) {
        last;
    } elsif ($remaining != 0) {
        # do a "nop" operation in case you decide to comment out "next"
        # to test below code in python
        $counter = $counter;
        next;
    }
    # below: should never happen unless "next" is commented out
    print "Now sending SOS message.\n";
    exit(4);
}

print "[[[[BOOM!]]]]\n";

# note: runs faster in perl than it does in python due to
# differences in interpretation times (probably from buffering)?
