#!/usr/bin/perl
# http://cgi.cse.unsw.edu.au/~cs2041/assignments/plpy/
# written by victor tse, 5075018
# (please read this in a text-colored editor...)

# ./plpy.pl examples/0/hello_world.pl | python3.5 -u > outmy
# ./examples/0/hello_world.py > out1
# diff outmy out1
use strict;
use warnings;

# grab the perl program (preserving newlines)
our @pl = <>; # shift chars off, then lines off when done
my @py = ();
our $n_indents = 0;   # python indentations must be precise
# set of modules to import
our %py_module_import = (); # set
# set of custom things to import (prefixed by "plpy_")
#   build python library of custom functions
#   (assume that order of custom functions NOT IMPORTANT)
our %py_custom_func_import = (); # set
our %py_custom_func_lib = (); # hash of everything
buildCustomFuncLib();

# ============== translate program ==============
my $hash_shebang = translateHashSheBang();
while (@pl) {
    push @py, translateLine(); # grabs line from $pl[0]
}
# ====== fix up missing stuff in reverse order ======
# add in the custom functions
for my $custom_func (sort keys %py_custom_func_import) {
    die if !exists $py_custom_func_lib{$custom_func};
    unshift @py, $py_custom_func_lib{$custom_func};
}
# add in the required modules
for my $module (sort keys %py_module_import) {
    die if !exists $py_module_import{$module};
    my $line = "import ". $py_module_import{$module} . "\n";
    unshift @py, $line;
}
# add in the hash shebang
unshift @py, $hash_shebang;
# print the python code
print @py;

#print join("\n", @py),"\n";
# note: can determine where a new line of python starts by scanning to
# an element with ";" and then looking at the element after (if any)

# additional issues:
#   probably doesnt handle multiline
#   assumes everything correctly indented
#   not sure if the matching for grouping actually works properly or not
#       TODO: differentiate grouping () with list, hash assignment by checking
#       if "=>" or "," are inside the brackets.

# standard set of rules for substring functions:
#   when entering a function, the first character is non-space
#   when exiting a function, $pl[0] has already been stripped of leading whitespace
#   whitespace tabs are translated after a "shift @pl" operation
#       tab count is updated on encountering a "{" or "}" (ie control flow)
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
    return $py_line . translateLeadingWhitespace();
}

# note: chain intermediate operations (word level) to translateLine()
sub translateLine {
    return "" if scalar @pl == 0;
    # ============= match to whitespace, comments, end-of-line =============
    if ($pl[0] eq "" || $pl[0] =~ /^[\s;]*#/ || $pl[0] =~ /^\s*;[\s;#]*$/) {
        # end-of-lines (compul ";") & comments (compul "#") can be passed unchanged
        # (newlines preserved already from the perl code)
        return shift(@pl) . translateLeadingWhitespace();
        # (actually, keeping the ";" is unnecessary in python)
    }
    if ($pl[0] =~/^(\s+)/) {
        # some in-line whitespace before a non-special, non-whitespace char
        # OR, current line continues onto the next line (no ";" encountered)
        # OR, just merges the empty line to the next line ("\n" separated)
        my $whitespace = $1;
        $pl[0] = substr($pl[0], $+[0]);
        # if operation continues on next line
        if (length $pl[0] == 0) {
            shift @pl;
            return $whitespace . translateLeadingWhitespace() . translateLine();
        }
        return $whitespace . translateLine();
    }
    # ================ match to a data type ================
    # note: matching to expression "<=>" mostly identical each time
    # (would modularise exp match but $1 doesn't transfer between functions)
    # TODO: match to "my", "our"
    if ($pl[0] =~ /^('.*?[^\\]')/ || $pl[0] =~ /^(".*?[^\\]")/ ||
        $pl[0] =~ /^('')/ || $pl[0] =~ /^("")/) {
        # match string (single / double, empty / non-empty)
        # check if part of an expression, if so, match expression afterwards
        my $result = translateString();
        $result = translateOperator($result) if isOperatorCmp();
        return $result;
    }
    if ($pl[0] =~ /^(\s*[\d.][\d._]*e[+\-]*[\d_]*\.?[\d_]*)/ ||
        $pl[0] =~ /^(\s*[\d.][\w.]*)/) {
        # match to numeric constant
        # NOTE: take out this match: ^[+\-]*
        #   /^(([+-]*\s*)*[\d.][\w+\-.]*)/ not precise enough (issue of signs)
        #   needs: [sign][digit/prefix/dp]...[exponential: e[repeat]]
        #   match exp separately, and match it first
        # check if part of an expression, if so, match expression afterwards
        my $result = translateNumber();
        $result = translateOperator($result) if isOperatorCmp();
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
        my $result = translateVariable();
        $result = translateOperator($result) if isOperatorCmp();
        return $result;
    }
    # ================ match to expression / operator ================
    # "<=>" has special priority since it has to be converted to a function
    # (see "data type" above)
    if (isOperatorNext() && !isOperatorCmp()) {
        # match to any operator not "<=>" (that gets matched with data types)
        return translateOperator("");
        # todo: fix spacing format if you have time
    }
    # ================ match to control flow / function ================
    if ($pl[0] =~ /^(if|elsif|else|while|for|foreach)[(;\s{]/) {
        # an expression shouldn't exist after this?
        # TODO: doesn't handle postfix control flow
        my $result = translateControlFlow();
        return $result;
    }

    if ($pl[0] =~ /^print[(;\s]/) { # print (function)
        my $result = translatePrint();
        $result = translateOperator($result) if isOperatorCmp();
        return $result;
    }
    # ======= lines we can't translate become comments =======
    my $temp = shift(@pl);
    return "#" . $temp . translateLeadingWhitespace();
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
    # grab arguments (can be expressions)
    my @print_args = translateFuncArgs();
    if (scalar @print_args) {
        $py_line .= join(",", @print_args);
        # force python print() to produce no automatic newline (un-pythonic...)
        $py_line .= ', end="", sep="")';
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
        my $whitespace = translateNextWhitespace();
        # end of args, restore the whitespace
        if ($pl[0] =~ /^[);]/) {
            $pl[0] = $whitespace . $pl[0];
            last;
        }
        # match to a comma separated argument
        if ($pl[0] =~ /^,(\s*)/) {
            # add to array
            $py_arg .= $whitespace;
            push @py_all_args, $py_arg;
            # reset py_arg and read next arg
            $pl[0] = substr $pl[0], $+[0];
            $py_arg = $1 . translateLine();
            next;
        }
        $py_arg .= $whitespace . translateLine();
        # [decrepit? uses a different implementation of translateExpression]
        #if (isOperatorNext()) {
        #    $result = translateOperator($result) if isOperatorCmp();
        #    $py_arg .= $whitespace . translateExpression($py_arg);
        #    next;
        #}
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
            my $next_next_char = substr($string, 0, 1); # pop off 1 char
            $string = substr($string, 1);
            # add the escaped character to result
            # consider perl-python special characters
            # TODO: doesn't handle perl special char: "\e" (what is py equiv?)
            if ($next_next_char =~ /[\\'"abfnrt]/) { # NO ANCHOR REQUIRED
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
    #die if ($pl[0] !~ /^(([+\-]*\s*)*[\d.][\w.]*(e[+\-]*\d*\.?\d*)?)/);
    #   ^ not precise enough: easier if you separate out exp form
    # integer, float, bin, oct, hex

    my $py_number;
    if ($pl[0] =~ /^(\s*[\d.][\d._]*e[+\-]*[\d_]*\.?[\d_]*)/) {
        # approximate match for an exp only
        $py_number = $1;
    } elsif ($pl[0] =~ /^(\s*[\d.][\w.]*)/) {
        # matches numbers with letters in it, very leniently
        $py_number = $1;
    } else {
        die;
    }
    $pl[0] = substr $pl[0], $+[0];
    # remove underscores (can't use tr)
    $py_number =~ s/_//g;
    # python3 prefix for an octal number is 0o or 0O
    $py_number =~ s/^(\D*)0/${1}0o/ if ($py_number =~ /^\D*0\d/);
    return $py_number . translateNextWhitespace();
    # don't need to handle weird case "5+.3.1" (prints "5") because perl -w will
    # complain that it is invalid code.
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
sub isOperatorCmp {
    return 1 if $pl[0] =~ /^(<=>)(\s*)/;
    return 0;
}
sub translateExpression {
    my ($arg) = @_;
    translateOperator($arg) . translateLine();
}
sub translateOperator {
    # match and translate one operator
    # input: first arg. WARNING: used only for "<=>".
    # WARNING: case "<=>" handles uniquely due to bracketing requirements
    # TODO: doesn't check with types
    die if !(isOperatorNext());
    my ($first_arg) = @_;
    $first_arg .= " " if ($first_arg !~ /\s$/);
    # todo above: should format the spacing better (this always inserts an
    # extra front space for any operator not "<=>").
    my $py_line = "";
    my $next = " ";
    # calling globals "$1" here doesn't work (on exit function call)?!
    # convert for special instances, otherwise just pass through
    if ($pl[0] =~ /^(<=>)(\s*)/) {
        # WARNING: special case: grabs second arg (bracketing requirements)
        $pl[0] = substr $pl[0], $+[0];
        $next = $2 if (defined $2 && $2 ne "");
        # "<=>" doesn't exist in python3, need to custom define
        $py_custom_func_import{"plpy_cmp"} = 1; # add to set
        $py_line .= "plpy_cmp(" . $first_arg . "," . $next;
        # grab 2nd argument and close the function
        $py_line .= translateLine() . ")" . translateNextWhitespace();
        return $py_line;
    }
    # all other less special cases: ($pl[0] updated after the if cases)
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
        $next = "" if ($1 eq "~");  # for nicer formatting?
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
sub translateLeadingWhitespace {
    # call this immediately after a "shift @pl" operation
    # which denotes the end of a line (going to the next line)
    return "" if scalar @pl == 0;
    # strip leading provided whitespace
    $pl[0] =~ s/^\s*//;
    # replace it by a standardised number of spaces
    return leadingWhitespace() x $n_indents; # x: repetition operator;
}
# WARNING: never call this unless in translateLeadingWhitespace
sub leadingWhitespace {
    # note: should i just make this a constant?
    return "    ";
    # note: don't use tab characters
    #return "\t" x $n_indents;
}
# "sub leadingBackspace": useless in python: indentation is highly specific

sub translateControlFlow {
    # matches to control flow
    # TODO: doesn't match for postfix control flow
    # TODO: investigate if braces compulsory in perl
    # TODO: doesn't handle if there are no args? (except "else")
    die if $pl[0] !~ /^(if|elsif|else|while|for|foreach)[(;\s{]/;
    my $command = $1;
    $pl[0] = substr $pl[0], $+[1];  # shift $pl[0] to after $1
    my $py_line = "";
    # "foreach" is the only one with unusual syntax
    # brackets are non-optional in control flow
    if ($command =~ /^(if|elsif|while)/) {
        # format command (only required by elsif)
        $command =~ s/s// if $command =~ /^elsif/;
        $py_line .= $command;
        # grab round brackets (assumes valid perl)
        # ... python doesn't need brackets, but it won't break with them
        $pl[0] =~ /^(\s*\()/;
        $py_line .= $1;
        $pl[0] = substr $pl[0], $+[0];
        # grab one arg (can be expression)
        $py_line .= translateLine(); # whitespace already grabbed
        while (isOperatorNext()) { # assume "<=>" handled by translateLine
            $py_line .= translateExpression("");
        }
        # close round brackets
        $pl[0] =~ /^(\s*\))/;
        $py_line .= $1 . ":";
        $pl[0] = substr $pl[0], $+[0];
    }
    elsif ($command =~ /^(else)/) {
        $py_line .= $command . ":"; # else doesn't have arguments
    }
    elsif ($command =~ /^(foreach)/) {
        # note: can't enclose entire argument in brackets
        $py_line = "for" . translateNextWhitespace();
        $py_line .= " " if $py_line eq "for";
        # grab one arg (shouldn't be expression)
        $py_line .= translateLine(); # whitespace already grabbed
        while (isOperatorNext()) { # assume "<=>" handled by translateLine
            # super defensive: it SHOULDN'T BE AN EXPRESSION
            $py_line .= translateExpression("");
        }
        # grab round bracket
        $pl[0] =~ /^(\s*\(\s*)/;
        $pl[0] = substr $pl[0], $+[0];
        $py_line .= " " if $py_line !~ / $/;
        $py_line .= "in ";
        # grab one argument (some list)
        $py_line .= translateLine();
        # close round brackets
        $pl[0] =~ /^(\s*\))/;
        $py_line .= ":";
        $pl[0] = substr $pl[0], $+[0];
    }
    elsif ($command =~ /^(for)$/) {
        # convert this to a while loop since c-style for not in python
        # grab round brackets (and spacing afterwards)
        $pl[0] =~ /^(\s*\(\s*)/;
        my $cust_header = "while" . $1;
        $pl[0] = substr $pl[0], $+[0];
        # grab three args (";" separated)
        # note: each of the "three args" could have subargs "," separated...
        my $initial_args = join(";",translateFuncArgs()) . ";\n";
        $pl[0] = substr $pl[0], $+[0] if ($pl[0] =~ /^(\s*;\s*)/);
        my $condition_args = join(" or ",translateFuncArgs()); # lazy spacing
        $pl[0] = substr $pl[0], $+[0] if ($pl[0] =~ /^(\s*;\s*)/);
        my $increment_args = join(";",translateFuncArgs()) . ";\n";
        $pl[0] = substr $pl[0], $+[0] if ($pl[0] =~ /^(\s*;\s*)/);
        # close round brackets
        $pl[0] =~ /^(\s*\))/;
        $cust_header .= $condition_args . $1 . ":";
        $pl[0] = substr $pl[0], $+[0];

        # begin formatting the while loop (cust_header already formatted)
        $py_line .= $initial_args . (leadingWhitespace() x $n_indents);
        $py_line .= $cust_header; # ready to grab braces
        # grab it here since increment_args will be out of scope outside the "if"
        $py_line .= translateBraces($increment_args);
    } else {
        die;
    }
    # grab contents (except if "for" loop, which grabbed it earlier)
    $py_line .= translateBraces("") if $command !~ /^for$/;
    # throwaway next whitespace if "}" is followed by "elsif" or "else"
    my $after_braces = translateNextWhitespace();
    if ($pl[0] =~ /^\s*elsif|else/) {
        return $py_line; # throw away the whitespaces (SPECIAL CASE)
    }
    return $py_line . $after_braces;
}

sub translateBraces {
    # starts scanning from beginning of "{" to end of "}"
    # grab everything within pair of "{", "}", excluding braces
    # input: end arguments to be inserted before closing the loop
    # WARNING: no defensive check implemented...
    my ($end_inserts) = @_;
    my $py_line = "";
    # find braces (could be on new line)
    while ($pl[0] !~ /^(\s*)\{/) {
        $py_line .= translateLine();
    }
    # $1 has local scope to "while", have to call it again
    $pl[0] =~ /^(\s*)\{/;
    # ... python doesn't use braces, so ignore them
    $py_line .= $1;
    $pl[0] = substr $pl[0], $+[0];
     # update indent count on entering "{"
    ++$n_indents;
    # find end braces
    while ($pl[0] !~ /^[;\s]*\}/) {
        $py_line .= translateLine();
    }
    # intermediate insertion of end args (indentation correct already)
    if ($end_inserts ne "") {
        $py_line .= $end_inserts . (leadingWhitespace() x $n_indents);
    }
    $pl[0] =~ /^([;\s]*)\}/;
    # restore indent count on exiting "}", and update $pl[0]
    --$n_indents;
    $pl[0] = substr $pl[0], $+[0]; # ignore braces
    # for later: add back in the ";" for sake of neatness
    my $captured_semicol = 0;
    $captured_semicol = 1 if ($1 =~ /;/); # DO NOT ANCHOR THIS
    # need to remove one level of indentation if on separate line
    my $indent = leadingWhitespace();
    if ($py_line =~ /$indent$/) {
        # use $-[0] this time to read to START of regex
        $py_line = substr $py_line, 0, $-[0];
    }
    # add back in the ";" for sake of neatness
    $py_line .= ";" if $captured_semicol;
    return $py_line;
}


###############################################
sub buildCustomFuncLib {
    # plpy_cmp function
    $py_custom_func_lib{"plpy_cmp"} = << 'endString';
def plpy_cmp(a,b):
    return (a>b)-(a<b)
endString
    # no more custom functions to add!
}

sub printDebug {
    my ($py_line) = @_;
    print("####[REMAINING PERL]###################\n");
    print join("",@pl),"\n";
    print("####[PYTHON CONVERTED]#################\n");
    print join("",@py),$py_line,"\n";
    print("#######################################\n");
}

sub printDebugPos {
     print "pl[0]:",$pl[0],"\n";
}

###############################################


#                   Random notes: (not necessarily complete)
#
###############################################
# ./plpy.pl examples/0/hello_world.pl | python3.5 -u > outmy
# ./plpy.pl examples/1/answer0.pl
#
# ./examples/0/hello_world.py > out1
# diff outmy out1
###############################################
# define the perl EBNS for the Recursive Descent Parser strategy:
# (though, what i'm currently writing hasn't turned out into one)
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
