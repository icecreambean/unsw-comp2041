#!/usr/bin/perl -w
@a = split(" ", "1 2 3");
for $i (@a) {
    print "1\n";
}

foreach $i (@a) {
    print "2\n";
}

for ($i = 0; $i < 3; $i++) {
    print "3\n";
}

foreach ($i = 0; $i < 3; $i++) {
    print "4\n";
}

while() {
    print "5\n";
    last;
}

while ( ) {
    print "6\n";
    last;
}

for (;;) {
    print "7\n";
    last;
}

for ($i = 0; ; --$i ) {
    print "8\n";
    last;
}

for ( ; ; --$i ) {
    print "9\n";
    last;
}
