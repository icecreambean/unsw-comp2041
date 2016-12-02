#!/usr/bin/perl
# written by andrewt@cse.unsw.edu.au September 2016
# as a starting point for COMP2041/9041 assignment
# http://cgi.cse.unsw.edu.au/~cs2041/assignments/plpy/
# remaining code written by victor tse, 5075018
use strict;
use warnings;
# tutor's recommendation: modularise everything
our @python_out = ();
while (my $line = <>) { # takes one .pl as input, opens the file
    chomp $line;
    if ($line =~ /^#!/ && $. == 1) {
        # translate #! line
        push @python_out, "#!/usr/local/bin/python3.5 -u";
    } elsif ($line =~ /^\s*#/ || $line =~ /^\s*$/) {
        # Blank & comment lines can be passed unchanged
        push @python_out, $line;
    } elsif ($line =~ /^\s*print\s*"(.*)\\n"[\s;]*$/) {
        # Python's print adds a new-line character by default
        # so we need to delete it from the Perl print statement
        push @python_out, "print(\"$1\")\n";
    } else {
        # Lines we can't translate are turned into comments
        push @python_out, "#$line\n";
    }
}
# write output to stdout
print join "\n", @python_out;
