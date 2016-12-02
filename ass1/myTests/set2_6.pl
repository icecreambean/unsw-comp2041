#!/usr/bin/perl
print("=========SET2_6=========\n");
$i = -1;
while ($i < 20) {
    $i = $i + 1;
    if ($i > 1 && $i < 5) {
        print "1 < $i < 5\n";
        next;
    }
    if ($i > 1 && $i < 6) {
        print "terminating on $i == 5\n";
        last;
    }
    print "$i == 0 or 1?\n";
}
