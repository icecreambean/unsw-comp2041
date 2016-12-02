#!/usr/bin/perl -w
# put your demo script here

# input: a list of space-separated arguments, eg:
# a b c d
# a b c andrewt d

$found = 0;
foreach $name (@ARGV) {
    if ($name eq "andrewt") {
        print "    Found $name, the wanted criminal.\n";
        $found = 1;
        last;
    } else {
        print ("    Not interested in $name.\n");
    }
}
print("Suspect search complete: ");

# a test of formatting
        if  ( $found == 1 )
    {
            print "criminal found\n";

        }
    else

            {
    print "nothing found\n";
                                }
