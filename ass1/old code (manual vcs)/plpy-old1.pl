#!/usr/bin/perl
# http://cgi.cse.unsw.edu.au/~cs2041/assignments/plpy/
# written by victor tse, 5075018

# ./plpy.pl examples/0/hello_world.pl | python3.5 -u > outmy
# ./examples/0/hello_world.py > out1
# diff outmy out1

use strict;
use warnings;
our @perl_code = ();
my @python_code = ();
our $cur_linepos = 0;      # line number in perl code (from 0)
our $cur_strpos = 0;       # pos in that line of perl code (from 0)

while (my $line = <>) { # takes one .pl as input, opens the file, reads it all
    chomp $line;
    push @perl_code, $line; # any alternatives to this? huge buffer...
}
# convert the perl code to python code
while ($cur_linepos < scalar @perl_code) {
    my @python_block = ();
    # check if empty string (occurs after chomping empty lines)
    push @python_block, "" if $perl_code[$cur_linepos] eq "";
    # check if hash-shebang
    push @python_block, processHashShebang() if (scalar @python_block == 0);
    # check all other types of code syntax
    push @python_block, processBlock() if (scalar @python_block == 0);
    push @python_code, @python_block;
    $cur_linepos++;
    $cur_strpos = 0;
}
# write output to stdout
print join("\n", @python_code),"\n";
#####################################################
# many of the below functions make use of global vars rather than taking args
# each function returns an array of strings (can be an empty array)

sub processHashShebang {
    my @python_block = ();
    my $cur_line = $perl_code[$cur_linepos];

    if ($cur_line =~ /^#!/ && $cur_linepos == 0 && $cur_strpos == 0) {
        # translate #! line
        push @python_block, "#!/usr/local/bin/python3.5 -u";
        $cur_strpos = scalar $cur_line; # end of string (to be good: global var)
    }
    return @python_block;
}

sub processBlock {
    my @python_block = ();
    # grab current line, check if not at end of line
    my $cur_line = $perl_code[$cur_linepos];
    return @python_block if ($cur_strpos >= (length $cur_line));
    # grab substring of current line (our working position)
    my $cur_line_subset = substr $cur_line, $cur_strpos; # work from cur strpos

    # test for appropriate line or block
    if ($cur_line_subset =~ /^[\s;]*#/ || $cur_line_subset =~ /^[\s;]*$/) {
        # end-of-lines & comments can be passed unchanged
        push @python_block, $cur_line_subset;
        $cur_strpos = scalar $cur_line; # end of string
    }
    elsif ($cur_line =~/^(\s)+/) {
        # just some in-line whitespace INBETWEEN two 'blocks'
        my $spacing = $1;
        $cur_strpos += $+[0];
        my @python_block2 = processBlock();
        # join the whitespace to the first element of the array
        $python_block2[0] = $spacing . $python_block2[0];
        push @python_block, @python_block2; # pushing onto empty pyblock
    }
    elsif ($cur_line =~ /^\s*print\s*\(?\s*"(.*)"\s*\)?[\s;]*$/ && $cur_strpos == 0) {
        # matches for print function, using double quotes "" (greedy match)
        # (TOFIX: print CAN be in-line combined with other funcs)
        # (TOFIX: doesn't handle string formatting)
        # (TODO: move this into a processFunction)
        my $string = $1;
        push @python_block, "print(\"$string\", end='')"; # easiest & laziest
        $cur_strpos = scalar $cur_line;
    }
    elsif ($cur_line =~ /^\s*print\s*\(?\s*'(.*)'\s*\)?[\s;]*$/ && $cur_strpos == 0) {
        # identical to above print() test, but for single quotes '' (greedy match)
        # (TOFIX: see above)
        my $string = $1;
        push @python_block, "print('$string', end='')";
        $cur_strpos = scalar $cur_line;
    }
    else {
        # Lines we can't translate are turned into comments
        push @python_block, "#$cur_line_subset";
        $cur_strpos = scalar $cur_line;
    }
    return @python_block;
}

# processFunction
# processExpression (two args, separated by a condition)
# processCondition
# processArg (for functions)



# http://stackoverflow.com/questions/87380/how-can-i-find-the-location-of-a-regex-match-in-perl
# http://stackoverflow.com/questions/399078/what-special-characters-must-be-escaped-in-regular-expressions
