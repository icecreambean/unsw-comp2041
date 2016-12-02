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
our $n_indents = 0;   # python indentations must be precise
# translate program
push @py, translateHashSheBang();
while (@pl) {
    push @py, translateLine(); # grabs line from $pl[0]
}
print @py;

#print join("\n", @py),"\n";
# note: can determine where a new line of python starts by scanning to
# an element with ";" and then looking at the element after (if any)

# additional issues:
#   probably doesnt handle multiline
#   assumes everything correctly indented
#   haven't taken into account grouping "()" - match in translateLine()?
#       TODO: differentiate grouping () with list, hash assignment by checking
#       if "=>" or "," are inside the brackets.

# standard set of rules for substring functions:
#   when entering a function, the first character is non-space
#   when exiting a function, $pl[0] has already been stripped of leading whitespace
#   [DISABLED]: whitespace tabs are translated after a "shift @pl" operation
#   anchor all regexes

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
    # ================ match to EXPRESSION (anything below here) ================
    # reasoning: operators are context driven (eg % is modulus OR hashing)
    #   (see below)
    # ================ match to a data type ================
    # note: matching to expression code identical except 3rd last line func call
    # (would modularise exp match but $1 doesn't transfer between functions)
    # "!" operator could occur anywhere....
    if ($pl[0] =~ /^!/) {
        return translateExpression(""); # "!" has no first arg
    }
    if ($pl[0] =~ /^('.*?[^\\]')/ || $pl[0] =~ /^(".*?[^\\]")/ ||
        $pl[0] =~ /^('')/ || $pl[0] =~ /^("")/) {
        # match string (single / double, empty / non-empty)
        #   (such regex precision above is unnecessary)
        # check if part of an expression, if so, match expression afterwards
        my $extracted = $1;
        $pl[0] = substr $pl[0], $+[0];
        # consider leading whitespace
        if ($pl[0] =~/^(\s+)/) {
            $extracted .= $1;
            $pl[0] = substr $pl[0], $+[0];
        }
        my $is_exp = isOperatorNext();  # no multiline support
        # restore pl for function call
        $pl[0] = $extracted . $pl[0];
        # ===== determine where to traverse =====
        my $result = translateString();
        # translateExpression has special usage
        $result = translateExpression($result) if $is_exp;
        return $result;
    }
    if ($pl[0] =~ /^(([+-]*\s*)*[\d.][\w+\-.]*)/) {
        # FIXME FIXME FIXME FIXME (not precise enough)
        # match to numeric constant
        # check if part of an expression, if so, match expression afterwards
        my $extracted = $1;
        $pl[0] = substr $pl[0], $+[0];
        # consider leading whitespace
        if ($pl[0] =~/^(\s+)/) {
            $extracted .= $1;
            $pl[0] = substr $pl[0], $+[0];
        }
        my $is_exp = isOperatorNext();  # no multiline support
        print $pl[0], "\n";
        # restore pl for function call
        $pl[0] = $extracted . $pl[0];
        # ===== determine where to traverse =====
        my $result = translateNumber();
        # translateExpression has special usage
        $result = translateExpression($result) if $is_exp;
        return $result;
        # (illegal to start anything with a digit unless it is numeric)
        # there might be an operator in front: [+-]\s*
        # note: a "%\s*" in front (with no prior argument) is read as a hash
    }
    if ($pl[0] =~ /^(\$\w+)/ || $pl[0] =~ /^(\${.*?})/) {
        # match to a variable (assumes valid syntax)
        # TODO: check if accessing an element of an array (suffix: "\s*[")
        # TODO: check if element of a hash (suffix: "\s*{")
        # checking for an index will require a separate function
        # TODO: match to perl's special variables
        # check if part of an expression, if so, match expression afterwards
        my $extracted = $1;
        $pl[0] = substr $pl[0], $+[0];
        # consider leading whitespace
        if ($pl[0] =~/^(\s+)/) {
            $extracted .= $1;
            $pl[0] = substr $pl[0], $+[0];
        }
        my $is_exp = isOperatorNext();  # no multiline support
        # restore pl for function call
        $pl[0] = $extracted . $pl[0];
        # ===== determine where to traverse =====
        my $result = translateVariable();
        # translateExpression has special usage
        $result = translateExpression($result) if $is_exp;
        return $result;
    }
    # ================ match to control flow / function ================
    #if ($pl[0] =~ /^(if|elsif|else|while|for|foreach)[(;\s]/) {
    # TODO
    #}

    if ($pl[0] =~ /^print[(;\s]/) { # print (function)
        my $result = translatePrint();
        # consider leading whitespace
        if ($pl[0] =~/^(\s+)/) {
            $result .= $1;
            $pl[0] = substr $pl[0], $+[0];
        }
        $result = translateExpression($result) if isOperatorNext();
        return $result;
    }

    # ======= lines we can't translate become comments =======
    my $temp = shift(@pl);
    return "#" . $temp;
    # [DISABLED] ======= lines we can't translate are unmodified =======
    #return shift(@pl);
}

sub translateNextWhitespace {
    # call at the end of a function to cleanup leading whitespace
    # for the next function
    return "" if $pl[0] !~ /^(\s*)/;
    $pl[0] = substr $pl[0], $+[0];
    return $1;
}
###############################################
sub translatePrint {
    # take off print, optional opening bracket
    #return "" if $pl[0] !~ /^print(\s*)/
    # TODO: handle "print;" for "$_" variable
    die if $pl[0] !~ /^print(\s*)/;
    my $py_line = "print$1(";
    $pl[0] = substr $pl[0], $+[0];
    # remove optional brackets
    my $opened_bracket = 0;  # false
    if ($pl[0] =~ /^\s*\(/) {
        $opened_bracket = 1; # true
        $pl[0] = substr $pl[0], $+[0];
    }
    # grab arguments
    my @print_args = translateFuncArgs();
    if (scalar @print_args) {
        $py_line .= join(",", @print_args);
        # force python print() to produce no automatic newline (un-pythonic...)
        $py_line .= ', end="")';
    } else {
        # TODO: handle $_ properly
        $py_line .= ")";
    }
    # remove optional closing bracket (in perl)
    if ($opened_bracket && $pl[0] =~ /^\s*\)/) {
        $pl[0] = substr $pl[0], $+[0];
    }
    return $py_line . translateNextWhitespace();
}

# WARNING: doesn't fixup whitespace before leaving function
# only call this inside a translateFunction
sub translateFuncArgs {
    # matches for sequence of comma separated arguments into an array
    # assumes this will be externally enclosed within appropriate brackets
    #
    # check if it has no args (ie next "arg" is end of line)
    return () if ($pl[0] =~ /^\s*[);]/);
    # grab sequential comma separated args
    my @py_all_args = ();
    my $py_arg = translateLine(); # there must be an arg
    while (1) {
        # match to an expression (by "shift" and "unshift")
        my $whitespace = translateNextWhitespace();
        if (isOperatorNext()) {
            $py_arg .= $whitespace . translateExpression($py_arg);
            next;
        }
        # OR, match to a comma separated argument
        if ($pl[0] =~ /^,(\s*)/) {
            # add to array
            $py_arg .= $whitespace;
            push @py_all_args, $py_arg;
            # reset py_arg and read next arg
            $pl[0] = substr $pl[0], $+[0];
            $py_arg = $1 . translateLine();
            next;
        }
        # no match, so restore the whitespace
        $pl[0] = $whitespace . $pl[0];
        last;
    }
    # add last element to array
    push @py_all_args, $py_arg;
    return @py_all_args;
}

sub translateString {
    if ($pl[0] =~ /^('')/ || $pl[0] =~ /^("")/) {
        # empty string case ('' or "")
        $pl[0] = substr($pl[0], $+[0]);
        return $1 . translateNextWhitespace();
    }
    # todo: match multiline strings? (loop? not sure if this is perl feature)
    if ($pl[0] =~ /^('.*?[^\\]')/ || $pl[0] =~ /^(".*?[^\\]")/) {
        # non-empty string case ('' or "")
        # has at least one char in it (total length at least 3)
        my $py_string = $1;
        $pl[0] = substr($pl[0], $+[0]);
        # handle variables embedded within string (using .format())
        $py_string = formatStringVariables($py_string);
        return $py_string . translateNextWhitespace();
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
            # TODO: doesn't handle perl special char: "\e" (what is py equiv?)
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
    } # @string_vars will never be undef
    return $new_string . translateNextWhitespace();
}

###############################################
sub translateVariable {
    # (contract): not an element of an array / hash
    # assumes that for "$1", correctly formatted (ie "$1a" is impossible)
    # (if you want more precision, steal from formatStringVariables())
    if ($pl[0] =~ /^\$(\w+)/ || $pl[0] =~ /^\${(.*?)}/) {
        $pl[0] = substr $pl[0], $+[0];
        return $1 . translateNextWhitespace();
    }
    die;
}

sub translateNumber {
    # assumes only numeric constants (any format) can start with a digit / dot
    # (the regex could be made more precise)
    # integer, float, bin, oct, hex
    #return "" if ($pl[0] !~ /^(([+-]*\s*)*[\d.][\w+\-.]*)/);
    die if ($pl[0] !~ /^(([+-]*\s*)*[\d.][\w+\-.]*)/);
    my $py_number = $1;
    $pl[0] = substr $pl[0], $+[0];
    $py_number =~ s/_//g; # remove underscores (can't use tr)
    # python3 prefix for an octal number is 0o or 0O
    $py_number =~ s/^(\D*)0/${1}0o/ if ($py_number =~ /^\D*0\d/);
    return $py_number . translateNextWhitespace();
    # don't need to handle weird case "5+.3.1" (prints "5") because perl -w will
    # complain that it is invalid code.
}

sub translateExpression {
    # input: takes in the 1st value starting the expression
    # recursively grabs the entire expression due to translateLine
    # TODO: fine for "1 + 3 <=> 2" since same prioritiy, but completely
    #       broken if grouping "1 + (3 <=> 2)" to be considered:
    #       will convert it to: "cmp( 1+(3 , 2) )"
    my ($arg) = @_;
    # defensive: consider whitespace (important for operator formatting)
    # no whitespace to be added for "!": only takes one argument
    $arg .= translateNextWhitespace();
    $arg .= " " if ($pl[0] !~ /^!/ && $arg !~ /\s$/);
    # WARNING: case "<=>" handles uniquely due to bracketing requirements
    # this case will grab the 2nd arg, so no need for intermediate translateLine()
    if ($pl[0] =~ /^(<=>)/) {
        return translateOperator($arg) . translateNextWhitespace();
    } # otherwise: (doesn't grab the 2nd arg)
    return translateOperator($arg) . translateLine() . translateNextWhitespace();
}
sub isOperatorNext {
    # matches for:
    # "="
    # "+", "-", "/", "%", "**", "*"
    # "||, ""&&", "!", "and", "or", "not"
    # "<", "<=", ">", ">=", "<=>", "!=", "=="
    # "|", "^", "&", "<<", ">>", "~"
    # PRIORITY: match from largest strlen to lowest strlen (26 possible)
    # (note: shared regex with translateOperator())
    # "and", "or", "not"
    return 1 if $pl[0] =~ /^(and|or|not)(\s*)/;
    # "<=>"
    return 1 if $pl[0] =~ /^(<=>)(\s*)/;
    # "||, ""&&", "<=", ">=, "!=", "==", "**", "<<", ">>"
    return 1 if $pl[0] =~ /^([|][|]|&&|<=|>=|!=|==|\*\*|>>|<<)(\s*)/;
    # "+", "-", "/", "%", "*", "!", "<", ">", "|", "^", "&", "~", "="
    return 1 if $pl[0] =~ /^([+\-\/%*!<>|^&~=])(\s*)/;
    return 0;
}
# WARNING: due to inconsistencies, don't use this unprotected:
# always make a call to translateExpression() instead
sub translateOperator {
    # match and translate one operator
    # WARNING: case "<=>" handles uniquely due to bracketing requirements
    die if !(isOperatorNext());
    my ($first_arg) = @_; # first_arg guaranteed to have whitespace at the end
    my $py_line = "";
    my $next = " ";
    # calling globals "$1" here doesn't work (on exit function call)?!
    # convert for special instances, otherwise just pass through
    if ($pl[0] =~ /^(<=>)(\s*)/) {
        # WARNING: special case: grabs second arg (bracketing requirements)
        $next = $2 if (defined $2 && $2 ne "");
        # "<=>" is a function in python
        $py_line .= "cmp(" . $first_arg . "," . $next;
        # grab 2nd argument and close the function
        $py_line .= translateLine() . ")" . translateNextWhitespace();
        return $py_line;
    }
    # all other less special cases:
    if ($pl[0] =~ /^([|][|])(\s*)/) {
        # TODO: incorrect by python standards (precedence issue)
        $next = $2 if (defined $2 && $2 ne "");
        $py_line .= $first_arg . "or" . $next;
    }
    elsif ($pl[0] =~ /^(&&)(\s*)/) {
        # TODO: incorrect by python standards (precedence issue)
        $next = $2 if (defined $2 && $2 ne "");
        $py_line .= $first_arg . "and" . $next;
    }
    elsif ($pl[0] =~ /^(and|or|not)(\s*)/ ||
           $pl[0] =~ /^(<=|>=|!=|==|\*\*|>>|<<)(\s*)/) {
        $next = $2 if (defined $2 && $2 ne "");
        $py_line .= $first_arg . $1 . $next;
    }
    elsif ($pl[0] =~ /^(!)(\s*)/) {
        # TODO: incorrect by python standards (precedence issue)
        # todo: any issues with brackets??
        $next = $2 if (defined $2 && $2 ne "");
        $py_line .= $first_arg . "not" . $next;
    }
    elsif ($pl[0] =~ /^([+\-\/%*<>|^&~=])(\s*)/) {
        # lowest priority match for 1 character occurrence
        $next = $2 if (defined $2 && $2 ne "");
        $py_line .= $first_arg . $1 . $next;
    }
    # WARNING: special operation (first_arg already removed from $pl[0])
    # WARNING: "<=>" option DOES NOT exit here because special case
    $pl[0] = substr $pl[0], $+[0];
    return $py_line . translateNextWhitespace();
}

#sub translateLowPredOperator {
#    # for perl's low precedence: "and", "or", "not"
#    # might need to run this after the remainder of the program has
#    # been generated (needs to add brackets? unsure otherwise)
#}

###############################################
sub translateLeadingWhitespace {   # TODO TODO - USE ME!
    # call this immediately after a "shift @pl" operation
    # which denotes the end of a line (going to the next line)
    return "" if scalar @pl == 0;
    # strip leading provided whitespace
    $pl[0] =~ s/^\s*//;
    return "\t" x $n_indents; # x: repetition operator
    # concatenate this immediately after "shift @pl"
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
