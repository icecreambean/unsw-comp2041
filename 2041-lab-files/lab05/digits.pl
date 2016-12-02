#!/usr/bin/perl -w
while ($line = <STDIN>) {
    $line =~ s/[0-4]/</g;
    $line =~ s/[6-9]/>/g;
    print $line;
}
