#!/usr/bin/perl
# http://cgi.cse.unsw.edu.au/~cs2041/assignments/plpy/
# written by victor tse, 5075018

# ./plpy.pl examples/0/hello_world.pl | python3.5 -u > outmy
# ./examples/0/hello_world.py > out1
# diff outmy out1
use strict;
use warnings;

# grab the perl program (preserving newlines)
our @pl = <>; # shift chars off, then lines off when done
my @py = ();
# ==================================TODO TODO TODO TODO TODO TODO
our $indent_level = 0;   # python indentations must be precise
push @py, translateHashSheBang();
while (@pl) {
    push @py, translateLine(); # grabs line from $pl[0]
}
print @py;

# additional issues:
#   probably doesnt handle multiline
#   assumes everything correctly indented
#   haven't taken into account grouping "()" - match in translateLine()?

###############################################
sub translateHashSheBang {
    # only call this function for the first line of code!
    return "" if scalar @pl == 0;
    my $py_line = "";
    if ($pl[0] =~ /^#!/) {
        # translate #! line
        shift @pl;
        $py_line .= "#!/usr/local/bin/python3.5 -u\n";
    }
    return $py_line;
}

# note: chain intermediate operations (word level) to translateLine()
sub translateLine {
    return "" if scalar @pl == 0;
    # ============= match to whitespace, comments, end-of-line =============
    if ($pl[0] =~ /^[\s;]*#/ || $pl[0] =~ /^\s*;[\s;#]*$/) {
        # end-of-lines (compul ";") & comments (compul "#") can be passed unchanged
        # (newlines preserved already from the perl code)
        return shift @pl;
        # (actually, keeping the ";" is unnecessary in python)
    }
    if ($pl[0] =~/^(\s+)/) {
        # some in-line whitespace before a non-special, non-whitespace char
        # OR, current line continues onto the next line (no ";" encountered)
        # OR, just merges the empty line to the next line ("\n" separated)
        my $whitespace = $1;
        $pl[0] = substr($pl[0], $+[0]);
        shift @pl if length $pl[0] == 0; # if operation continues on next line
        return $whitespace . translateLine();
    }
    # ================ match to a data type ================
    if ($pl[0] =~ /^'.*?[^\\]'/ || $pl[0] =~ /^".*?[^\\]"/ ||
        $pl[0] =~ /^''/ || $pl[0] =~ /^""/) {
        # match string (data type) (single / double, empty / non-empty)
        # (such regex precision above is unnecessary)
        return translateString();
    }
    if ($pl[0] =~ /^\$\w+/ || $pl[0] =~ /^\${.*?}/) {
        # match to a variable (data type)
        # TODO: check if accessing an element of an array (suffix: "\s*[")
        # TODO: check if element of a hash (suffix: "\s*{")
        # checking for an index will require a separate function
        # TODO: match to perl's special variables
        return translateVariable();
    }
    if ($pl[0] =~ /^(([+-]*\s*)*[\d.][\w+-.]*)/) {
        # match to numeric constant
        return translateNumber();
        # (illegal to start anything with a digit unless it is numeric)
        # there might be an operator in front: [+-]\s*
        # note: a "%\s*" in front (with no prior argument) is read as a hash
    }
    # ================ match to some special operators ================
    if ($pl[0] =~ /^=[^=]/) {
        # match to assignment operator (assume lhs of operator is correct)
        return translateAssignment();
    }

    # ================ match to a function ================
    if ($pl[0] =~ /^print\b/) { # print (function)
        return translatePrint();
    }

    # ======= lines we can't translate are just passed back out =======
    my $temp = shift(@pl);
    return "#" . $temp;
    #return shift(@pl);
}
###############################################
sub translatePrint {
    # take off print, optional opening bracket
    #return "" if $pl[0] !~ /^print(\s*)/;
    die if $pl[0] !~ /^print(\s*)/;
    my $py_line = "print$1(";
    $pl[0] = substr $pl[0], $+[0];
    # TODO: handle $_ for print;
    # remove optional brackets
    my $opened_bracket = 0;  # false
    if ($pl[0] =~ /^\s*\(/) {
        $opened_bracket = 1; # true
        $pl[0] = substr $pl[0], $+[0];
    }
    # grab a part of a line (data / variable, etc.)
    $py_line .= translateLine();
    while (1) {
        # match to an expression
        if (isExpressionNext()) {
            $py_line .= translateExpression();
            next;
        }
        # OR, match to a comma separated argument
        if ($pl[0] =~ /(\s*,\s*)/) {
            $py_line .= $1;
            $pl[0] = substr $pl[0], $+[0];
            $py_line .= translateLine();
            next;
        }
        last;
    }
    # (todo: replace below method with something more pythonic)
    # always force python print() to produce no automatic newline
    $py_line .= ', end="")';
    # remove optional closing bracket (in perl)
    if ($opened_bracket && $pl[0] =~ /^\s*\)/) {
        $pl[0] = substr $pl[0], $+[0];
    }
    return $py_line;
}

sub translateString {
    if ($pl[0] =~ /^('')/ || $pl[0] =~ /^("")/) {
        # empty string case ('' or "")
        $pl[0] = substr($pl[0], $+[0]);
        return $1;
    }
    # todo: match multiline strings? (loop? not sure if this is perl feature)
    if ($pl[0] =~ /^('.*?[^\\]')/ || $pl[0] =~ /^(".*?[^\\]")/) {
        # non-empty string case ('' or "")
        # has at least one char in it (total length at least 3)
        my $py_string = $1;
        $pl[0] = substr($pl[0], $+[0]);
        # handle variables embedded within string (using .format())
        $py_string = formatStringVariables($py_string);
        return $py_string;
    }
    #return "";  # something failed
    die;
}
sub formatStringVariables {
    # formats perl string into python "blah".format(args)
    #   input: a string with args
    #   match to $digit, $letter:word, ${word}
    #   TODO: this doesn't handle array / hash (let alone multidimensional)
    #   TODO: doesn't actually handle $1 properly, python sees arg "1"
    my ($string) = @_;
    my $new_string = "";
    my @string_vars = ();
    # regex: /(?<=[^\\])(?:\$(\d+)|\$([^\d{}]\w+)|\$\{(\w+)\})/ doesn't work
    # find variable and replace by {}
    while (length $string) {
        my $next_char = substr($string, 0, 1); # pop off next char
        $string = substr($string, 1);
        # check character
        if ($next_char eq '\\') {
            # for valid perl syntax, encountering "\" with
            # escape_on == 0 implies next char exists (comes in char pairs)
            # next char must be escaped
            my $next_next_char = substr($string, 0, 1); # pop off
            $string = substr($string, 1);
            # add the escaped character to result
            # consider perl-python special characters
            # TODO: doesn't handle perl special char: "\e"
            if ($next_next_char =~ /[\\'"abfnrt]/) {
                $new_string .= $next_char . $next_next_char;
            } else {
                $new_string .= $next_next_char;
            }
            next;
        }
        elsif ($next_char eq '$') {
            # "$" NOT escaped, hence must be a variable
            # TODO: handle array / hash indexing
            #
            # note: if $1 == "C" and matching /$1a/, result matches for "Ca"
            # not working below:
            #my $var = $string =~ /^(?:(\d+)|([^\d{}]\w+)|\{(\w+)\})/;
            my $var;
            if ($string =~ /^(\d+)/ || $string =~ /^([a-z_]\w*)/i ||
                    $string =~ /^\{(\w+)\}/) {
                $var = $1;
            } else {
                # something failed, let's just ignore this variable
                $new_string .= $next_char;
                next;
            }
            # regex successful
            $new_string .= "{}"; # for python3 .format()
            # TODO: (modify var if var is array / hash)
            push @string_vars, $var;
            $string = substr $string, $+[0];
            next;
        }
        $new_string .= $next_char; # for non-interesting characters
    }
    #print join(",",@string_vars),"\n"; # debug only
    # ".format(" then add in the variables, then ")"
    if (scalar @string_vars) {
        $new_string .= ".format(" . join(", ", @string_vars) . ")";
    }
    return $new_string;    # @string_vars will never be undef
}

###############################################
sub translateVariable {
    # (contract): not an element of an array / hash
    if ($pl[0] =~ /^\$(\w+)/ || $pl[0] =~ /^\${(.*?)}/) {
        $pl[0] = substr $pl[0], $+[0];
        return $1;
    }
    #return "";
    die;
}

sub translateNumber {
    # assumes only numeric constants (any format) can start with a digit / dot
    # (the regex could be made more precise)
    # integer, float, bin, oct, hex
    #return "" if ($pl[0] !~ /^(([+-]*\s*)*[\d.][\w+-.]*)/);
    die if ($pl[0] !~ /^(([+-]*\s*)*[\d.][\w+-.]*)/);
    my $py_number = $1;
    $pl[0] = substr $pl[0], $+[0];
    $py_number =~ s/_//g; # remove underscores (can't use tr)
    # python3 prefix for an octal number is 0o or 0O
    $py_number =~ s/^(\D*)0/${1}0o/ if ($py_number =~ /^\D*0\d/);
    return $py_number;
    # don't need to handle weird case "5+.3.1" (prints "5") because perl -w will
    # complain that it is invalid code.
}

sub isExpressionNext {
    # shared regex with: translateExpression
    return 1 if $pl[0] =~ /^(\s*([+\-\/%]|[*]{2}|[*][^*])\s*)/;
    return 0;
}
sub translateExpression {
    # match one operator, then another variable /function call
    #return "" if $pl[0] !~ /^(\s*([+\-*\/%]|\*\*)\s*)/;
    # shared regex with: isExpressionNext
    die if $pl[0] !~ /^(\s*([+\-\/%]|[*]{2}|[*][^*])\s*)/;
    my $py_line = $1;
    $pl[0] = substr $pl[0], $+[0];
    $py_line .= translateLine();
    return $py_line;
}

sub translateAssignment {
    # for assigning contents to some data structure
    #return "" if ($pl[0] !~ /(^=[^=]\s*)/);
    die if ($pl[0] !~ /(^=[^=]\s*)/);
    my $py_line = $1;
    $pl[0] = substr $pl[0], $+[0];
    # grab a variable / function call, etc.
    $py_line .= translateLine();
    # continue matching expression while operators remain
    while (isExpressionNext()) {
        $py_line .= translateExpression();
    }
    return $py_line;
}

###############################################
# ./plpy.pl examples/0/hello_world.pl | python3.5 -u > outmy
# ./plpy.pl examples/1/answer0.pl
#
# ./examples/0/hello_world.py > out1
# diff outmy out1
###############################################
# define the perl EBNS for the Recursive Descent Parser strategy:
# (add to the EBNS as we go through the sets)

# program = {line}
# line =  comment | function_header | data_type   && {termination chars}
# function = "print" string && {optional "(" ")"}
# string = <quote> (.*) <\quote>

# variable = "$" name
# numeric constant  = [-]integer | binary (0b..) | octal (0..) | hex (0x...) |
#                     exponential (integer[.integer]"e"integer) | integer.integer
#   i.e.: prefix can be: (-\s*)?0[bx]?
#   suffix can be: (.integer)?("e"integer)?     (type dependent)
#   also, ignore underscore characters INBETWEEN digits in perl
#   required to strip out underscore characters before converting to python
#
# operator = "+" | "-" | "*" | "/" | "%" | "**"
# expression = ("+" | "-") (variable | number) operator (operator | variable | number | expression)
#   initial % doesn't work in python unless insert a "0" in front
# assignment = variable "=" (expression | function)
