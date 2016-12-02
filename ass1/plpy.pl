#!/usr/bin/perl
# http://cgi.cse.unsw.edu.au/~cs2041/assignments/plpy/
# written by victor tse, 5075018
# (please read this in a text-colored editor...)

# ./plpy.pl examples/0/hello_world.pl | python3.5 -u > outmy
# ./examples/0/hello_world.py > out1
# diff outmy out1
use strict;
use warnings;

# bunch of random globals due to poor design choices:
our $n_indents = 0;   # python indentations must be precise
our $check_cmp = 1;   # on/off to control whether to do the "<=>" check or not
our $check_double_dot = 1; # for ".."

# grab the perl program (preserving newlines)
our @pl = <>; # shift chars off, then lines off when done
my @py = ();
# set of modules to import
our %py_module_import = (); # set
# set of custom things to import (prefixed by "plpy_")
#   build python library of custom functions
#   (assume that order of custom functions NOT IMPORTANT)
our %py_custom_func_import = (); # set
our %py_custom_func_lib = (); # hash of everything
# set of arrays to define
# [UNIMPLEMENTED]: (val is number of initial elements in array)
# currently: is a set
our %py_array_define = ();
buildCustomFuncLib();

# ============== translate program ==============
my $hash_shebang = translateHashSheBang();
while (@pl) {
    push @py, translateLine(); # grabs line from $pl[0]
}
# ====== fix up missing stuff in reverse order ======
# remove filename from sys argv
if (defined $py_module_import{"sys"}) {
    # matches python's argv to perl's
    my $line = "sys.argv.pop(0)\n";
    unshift @py, $line;
    # discard result (guaranteed there is at least one element in
    # this array... the filename)
}
# add in the arrays
for my $array (sort keys %py_array_define) {
    my $line = $array . " = []\n";
    # [UNIMPLEMENTED]:
    # preinitialise since perl can just write to an index it wants
    #my $line = $array . " = [None] * " . $py_array_define{$array} . "\n";
    unshift @py, $line;
}
# add in the custom functions
for my $custom_func (sort keys %py_custom_func_import) {
    die if !exists $py_custom_func_lib{$custom_func};
    unshift @py, $py_custom_func_lib{$custom_func};
}
# add in the required modules
for my $module (sort keys %py_module_import) {
    my $line = "import ". $module . "\n";
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
#   doesnt handle multiline
#   doesnt handle typing
#   only implemented set 0 to (most of) set 3

# standard set of rules for substring functions:
#   when entering a function, the first character is non-space
#   when exiting a function, $pl[0] has already been stripped of leading whitespace
#       TODO: this standard is wrong; whitespace is a huge issue and should be
#       considered before the start of any translation, not at the end.
#   whitespace tabs are translated after a "shift @pl" operation
#       tab count is updated on encountering a "{" or "}" (ie control flow)
#   anchor all regexes
#   global params are required for some operations. use them like an assembler would

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
    # want to keep the hash shebang separate to the next whitespace
    push @py, translateLeadingWhitespace();
    return $py_line; # write this to @py manually later
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
    if ($pl[0] =~ /^(\s*;\s*)/) {
        # not anchored to end of string, represents an in-line ";"
        $pl[0] = substr $pl[0], $+[0];
        return $1;
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
        $result = translateOtherOperators($result);
        # doesn't handle for ".." since it'd break in python anyway
        # (from unimplemented functionality)
        return $result;
    }
    if (isNumberNext()) {
        # match to numeric constant
        # NOTE: take out this match: ^[+\-]*
        #   /^(([+-]*\s*)*[\d.][\w+\-.]*)/ not precise enough (issue of signs)
        #   needs: [sign][digit/prefix/dp]...[exponential: e[repeat]]
        #   match exp separately, and match it first
        #   NOTE: with introduction of ".." operator, fix regex precision
        #   (mostly fixed...)
        # check if part of an expression, if so, match expression afterwards
        my $result = translateNumber(1);
        # todo: ignore underscores afterwards? add a space if no trailing space
        # in result as consequence of underscores? (either way i can't handle
        # dot operator yet anyway)
        $result = translateOtherOperators($result);
        return $result;
        # (illegal to start anything with a digit unless it is numeric)
        # there might be an operator in front: [+-]\s*
        # note: a "%\s*" in front (with no prior argument) is read as a hash
    }

    if ($pl[0] =~ /^(\@\s*\w+)/ || $pl[0] =~ /^(\@\s*\{\s*(\w+)\s*\})/) {
        # match to an array
        my $result = translateArray();
        # don't think i need to call: translate Other Operators
        return $result;
    }
    if ($pl[0] =~ /^\$#([a-z_]\w*)/i) {
        # match to array, index of last element
        my $array_name = $1;
        # code duplication = bad. will fix if time_available > 0.
        if ($array_name eq "ARGV") {    # case matters
            $py_module_import{"sys"} = 1;
            $array_name = "sys.argv";
        } else {
            $py_array_define{$array_name} = 1;
        }
        $pl[0] = substr $pl[0], $+[0];
        # extra brackets for safety
        return "(len($array_name) -1)" . translateNextWhitespace();
    }

    # match to PRE increment / decrement of a variable
    # python can't handle differences between prefix and postfix?
    # python can't handle it being on a commmon line?
    if ($pl[0] =~ /^(\+\+|\-\-)\s*\$\s*(\w+)/ ||
        $pl[0] =~ /^(\+\+|\-\-)\s*\$\s*\{\s*(\w+)\s*\}/)
    {
        my $operator = $1; # guaranteed 2 chars
        my $var = $2;
        $pl[0] = substr $pl[0], $+[0];
        $operator =~ s/[+-]$/=/; # must be end-anchored
        return $var . " " . $operator . " 1" . translateNextWhitespace();
        # hope and pray nothing but [;)] after, or python code makes no sense
    }
    # match to POST increment / decrement of a variable
    # python can't handle ... same as above?
    if ($pl[0] =~ /^\$\s*(\w+)\s*(\+\+|\-\-)/ ||
        $pl[0] =~ /^\$\s*\{\s*(\w+)\s*\}\s*(\+\+|\-\-)/)
    {
        my $operator = $2; # guaranteed 2 chars
        my $var = $1;      # note reverse order (compared to pre)
        $pl[0] = substr $pl[0], $+[0];
        $operator =~ s/[+-]$/=/; # must be end-anchored
        return $var . " " . $operator . " 1" . translateNextWhitespace();
        # hope and pray nothing but [;)] after, or python code makes no sense
    }
    # below: too simple
    #if ($pl[0] =~ /^(\$\s*\w+\s*\[\s*\d+\s*\])/ ||
    #    $pl[0] =~ /^(\$\s*\{\s*\w+\s*\[\s*\d+\s*\]\s*\})/)
    # below: changed \d+ to (.*?)
    if ($pl[0] =~ /^(\$\s*\w+\s*\[\s*.*?\s*\])/ ||
        $pl[0] =~ /^(\$\s*\{\s*\w+\s*\[\s*.*?\s*\]\s*\})/)
    {
        # match to array element ${..[..]}
        my $result = translateArrayElement();
        $result = translateOtherOperators($result);
        return $result;
    }

    if ($pl[0] =~ /^(\$\s*\w+)/ || $pl[0] =~ /^(\$\s*\{\s*(\w+)\s*\})/) {
        # match to a variable (assumes valid syntax)
        # todo: check if accessing an element of an array (suffix: "\s*[")
        # todo: check if element of a hash (suffix: "\s*{")
        #   checking for an index will require a separate function
        # todo: match to perl's special variables
        # check if part of an expression, if so, match expression afterwards
        # (this regex only matches to "normal" variables)
        my $result = translateVariable();
        $result = translateOtherOperators($result);
        return $result;
    }
    # ================ match to function ================
    if ($pl[0] =~ /^print[(;\s]/) { # print (function)
        my $result = translatePrint();
        $result = translateOtherOperators($result);
        return $result;
    }
    if ($pl[0] =~ /^chomp[(;\s]/) {
        # simplest version of chomp (one variable)
        # assumes $/ eq "\n"
        my $result = translateChomp();
        # assume not possible to call it as part of an expression afterwards...
        # since chomping takes a reference, so in py, needs an assignment
        return $result;
    }
    if ($pl[0] =~ /^exit[(;\s]/) {
        my $result = translateExit();
        return $result;
    }
    if ($pl[0] =~ /^join[(;\s]/) {
        my $result = translateJoin();
        # assume can't take an expression afterwards because lazy
        return $result;
    }
    if ($pl[0] =~ /^split[(;\s]/) {
        # split function: implementation only handles two args, can't handle
        # regex as an argument (ie very basic...)
        my $result = translateSplit();
        # assume can't take an expression afterwards because lazy
        return $result;
    }
    # TODO: implement split

    # ================ match to grouping ================
    # should it be this low priority?
    # note also does a match for "<=>","cmp" in here (other operators ok)
    # note: matches for ".."
    if ($pl[0] =~ /^\(/) {
        return translateBrackets();
    }
    # ================ match to control flow ================
    # NOTE: super low priority to prevent conflicts with function names
    if ($pl[0] =~ /^(if|elsif|else|while|for|foreach)[(;\s{]/) {
        # an expression shouldn't exist after this?
        # TODO: doesn't handle postfix control flow
        my $result = translateControlFlow();
        return $result;
    }
    if ($pl[0] =~ /^(next)[(;\s]/) { # is this too lenient?
        $pl[0] = substr $pl[0], $+[1];
        return "continue" . translateNextWhitespace();
    }
    if ($pl[0] =~ /^(last)[(;\s]/) { # is this too lenient?
        $pl[0] = substr $pl[0], $+[1];
        return "break" . translateNextWhitespace();
    }
    # ================ match to expression / operator ================
    # NOTE: super low priority to prevent conflicts with function names
    # "<=>" has special priority since it has to be converted to a function
    # prefix and postfix increment / decrement are also special, etc.

    # NOTE: how to resolve <STDIN> embedded within a while loop?
    # currently hacked in a hard coded solution in translate Control Flow
    # (no idea how to resolve in non-hard coded manner).
    if ($pl[0] =~ /^(<STDIN>)/i) {
        # match to "<STDIN>": perl won't allow spaces between the brackets
        # can be STDIN or stdin (ie ignore case)
        $pl[0] = substr $pl[0], $+[0];
        $py_module_import{"sys"} = 1;
        return "sys.stdin.readline()" . translateNextWhitespace();
        # spacing shouldn't be an issue in valid perl (limits where <STDIN>
        # can be located: must be with some kind of assignment)
    }
    if (isOperatorNext() && $pl[0] !~ /^(<=>|cmp)/) {
        # match to any operator not "<=>" (that gets matched with data types)
        # or, to string's "cmp" (TODO: check if regex too weak?)
        return translateOperator();
        # todo: fix spacing format if you have time
    }
    # ======= lines we can't translate become comments =======
    my $temp = shift(@pl);
    return "#" . $temp . translateLeadingWhitespace();
    # [DISABLED] ======= lines we can't translate are unmodified =======
    #return shift(@pl);
}

sub translateBrackets {
    die if $pl[0] !~ /^\(/;
    $pl[0] = substr $pl[0], 1;
    # setup
    my $py_line = "(" . translateNextWhitespace();
    # save global params
    my $prev_check_cmp = $check_cmp;
    my $prev_check_double_dot = $check_double_dot;
    # reset global params for new search
    $check_cmp = 1;
    $check_double_dot = 1;
    # search for end bracket
    while ($pl[0] !~ /^\)/) {
        $py_line .= translateLine();
    }
    $pl[0] = substr $pl[0], 1; # add on the ")"
    $py_line .= ")" . translateNextWhitespace();
    # restore global params
    $check_cmp = $prev_check_cmp;
    $check_double_dot = $prev_check_double_dot;
    # if one of the other operators occurs in same line sometime after
    $py_line = translateOtherOperators($py_line);

    return $py_line . translateNextWhitespace();
}

sub translateNextWhitespace {
    # call at the end of a function to cleanup leading whitespace
    # for the next function
    # NOTE: breaks if no semicolon at end of perl line
    # by indirect method notation? (somewhat fixed in a hacky manner)
    return "" if !defined $pl[0] || $pl[0] eq ""; # not incorrect
    return "" if $pl[0] !~ /^(\s*)/;
    $pl[0] = substr $pl[0], $+[0];
    return $1;
}

###############################################
# BELOW: translation functions. ordered approximately by SET no.
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
    # for when you don't require a ";" at the end (in perl)
    my $is_indirect_method = 0;
    if (scalar @print_args) {
        $py_line .= join(",", @print_args);
        # force removal of "\n" if indirect method notation
        if ($py_line =~ /\n$/) {
            $py_line =~ s/\n$//;
            $is_indirect_method = 1;
        }
        # force python print() to produce no automatic newline (un-pythonic...)
        $py_line .= ', end="", sep="", flush=True)';
        $py_line .= ";\n" if $is_indirect_method;
    } else {
        # TODO: handle $_ properly
        $py_line .= ")";
        # does this support indirect method notation?
        # doesn't matter either way, because i don't support "$_"
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
    # (translate Comma Separated) would be a better name...
    #
    # FIXME: doesn't support multiline because this was changed to support
    # indirect method notation in a hacky way (see examples/3/five.pl)
    #
    # check if it has no args (ie next "arg" is end of line)
    return () if ($pl[0] =~ /^\s*[);]/);
    # grab sequential comma separated args
    my @py_all_args = ();
    my $py_arg = translateLine(); # there must be an arg
    while (1) {
        my $whitespace = translateNextWhitespace();
        # also need to consider: (indirect method notation)
        if ($pl[0] eq "") {
            # restore the whitespace
            # note whitespace could also be ""
            $pl[0] = $whitespace;
            last;
        }
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
    #   NOTE: only handles one dimensional arrays
    #   NOTE: doesn't handle "$#array_name" (this is too much work..)
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
                $new_string .= $next_next_char; # handles "\$"
            }
            next;
        }
        elsif ($next_char eq '$') {
            # "$" NOT escaped, hence must be a variable
            # TODO: (probably also issues with underscore, oh well...)
            # TODO: handle array / hash indexing (no arithmetic in here
            # but still issues if the index is a variable name)
            # (best to match in segments: if you have the time...)
            #
            # note: if $1 == "C" and matching /$1a/, result matches for "Ca"
            # not working below:
            #my $var = $string =~ /^(?:(\d+)|([^\d{}]\w+)|\{(\w+)\})/;
            my $var;
            #if ($string =~ /^\s*(\w+)\[\s*(\d+)\s*\]/ ||
            #    $string =~ /^\s*\{\s*(\w+)\s*\[\s*(\d+)\s*\]\s*\}/)
            if ($string =~ /^\s*(\w+)\[\s*(\d+|\$\s*\w+)\s*\]/ ||
                $string =~ /^\s*\{\s*(\w+)\s*\[\s*(\d+|\$\s*\w+)\s*\]\s*\}/)
            {
                # for an array element ("duplication" of code... not so great)
                # (see: translate Array Element)
                # NOTE: regex slightly different: unbracketed, can't have spaces
                #       between final var name character and "["
                # ALSO, only does a very simple match for "$" because running
                # out of time
                my $array_name = $1;
                my $index = $2;
                # FIXME: cheap and nasty reading of a variable (simple format only)
                if ($index =~ /^(\$\s*)/) {
                    $index = substr $index, $+[0];
                    # TODO: format if special variable, etc.
                }

                if ($array_name eq "ARGV") {    # case matters
                    $py_module_import{"sys"} = 1;
                    $array_name = "sys.argv";
                    #$index++;
                    # NOTE: resolved way way above (this was bugged anyway)
                } else {
                    $py_array_define{$array_name} = 1;
                }
                $var = $array_name . "[" . $index . "]";
            }
            elsif ($string =~ /^\s*(\d+)/ || $string =~ /^\s*([a-z_]\w*)/i ||
                $string =~ /^\s*\{\s*(\w+)\s*\}/)
            {
                $var = $1;
            }
            else {
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
        elsif ($next_char =~ /([{}])/) { # NO ANCHOR REQUIRED
            # "{" and "}" have special meaning in format string
            # escape it by doubling the braces
            $new_string .= "$1$1";
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
    if ($pl[0] =~ /^\$\s*(\w+)/ || $pl[0] =~ /^\$\s*\{\s*(\w+)\s*\}/) {
        $pl[0] = substr $pl[0], $+[0];
        return $1 . translateNextWhitespace();
    }
    die;
}

sub isNumberNext {
    # note implementing dot operators require numbers to be precisely read
    # TODO: underscore still not precise enough? (ie for leading 0 numbers)
    # OR, need to alter translateLine to read and ignore "_" after a "0__.4"
    # TODO: should rework this... (especially exponentials)
    # scientific notation
    #   "0e0" valid but "00e0" is not
    #   FIXME: won't work with dot operator unless translateLine altered?
    # this doesn't work for exponentials:
    # /^((0|[1-9][\d_]*)?(\.[\d_]+)?[+\-]*e(0|[1-9][\d_]*)?(\.[\d_]+)?)/);
    #
    # a integer or a decimal:
    # /(0?\.[\d_]+|[1-9][\d_]*\.[\d_]+|0|[1-9][\d_]*)/

    # float (decimal place)
    #   FIXME: won't work with dot operator unless translateLine altered?
    return 1 if ($pl[0] =~ /^([+\-\s]*\.[\d_]+)/);
    return 1 if ($pl[0] =~ /^([+\-\s]*0\.[\d_]+)/); # could merge this and above
    return 1 if ($pl[0] =~ /^([+\-\s]*[1-9][\d_]*\.[\d_]+)/);
    # hex (... see below)
    return 1 if ($pl[0] =~ /^([+\-\s]*0x[\w_]+)/);
    # bin (digits afterwards must be legal for valid perl)
    return 1 if ($pl[0] =~ /^([+\-\s]*0b[\d_]+)/);
    # octal (illegal to start with 0 and have "8","9","." afterwards)
    return 1 if ($pl[0] =~ /^([+\-\s]*0[\d_]+)/);
    # integer only (lower precedence than octal)
    return 1 if ($pl[0] =~ /^([+\-\s]*[0-9][\d_]*)/);
    # handle scientific in translateNumber
    return 0;
}
sub translateNumber {
    # assumes only numeric constants (any format) can start with a digit / dot
    # (the regex could be made more precise)
    #die if ($pl[0] !~ /^(([+\-]*\s*)*[\d.][\w.]*(e[+\-]*\d*\.?\d*)?)/);
    #   ^ not precise enough: easier if you separate out exp form
    # integer, float, bin, oct, hex
    my ($consider_scientific) = @_; # 0 for no, 1 for yes
    my $py_number;
    my $maybe_scientific = 1;
    # note: same issues as in isNumberNext
    if ($pl[0] =~ /^([+\-\s]*\.[\d_]+)/) {
        # float (decimal place)
        $py_number = $1;
    }
    elsif ($pl[0] =~ /^([+\-\s]*0\.[\d_]+)/) { # float
        $py_number = $1;
    }
    elsif ($pl[0] =~ /^([+\-\s]*[1-9][\d_]*\.[\d_]+)/) { # float
        $py_number = $1;
    }
    elsif ($pl[0] =~ /^([+\-\s]*0x[\w_]+)/) { # hex
        $py_number = $1;
        $maybe_scientific = 0;
    }
    elsif ($pl[0] =~ /^([+\-\s]*0b[\d_]+)/) { # bin
        $py_number = $1;
        $maybe_scientific = 0;
    }
    elsif ($pl[0] =~ /^([+\-\s]*0[\d_]+)/) { # octal
        $py_number = $1;
        $maybe_scientific = 0;
    }
    elsif ($pl[0] =~ /^([+\-\s]*[0-9][\d_]*)/) { # integer
        $py_number = $1;
    }
    else {
        die; # invalid func call
    }
    # update $pl[0]
    $pl[0] = substr $pl[0], $+[0];
    # if scientific (DON'T strip whitespace)
    # (it shouldn't conflict with hexadecimal since that grabs all \w)
    if ($consider_scientific && $maybe_scientific && $pl[0] =~ /^(e[+\-]*)/i) {
        my $second_part = $1;
        $pl[0] = substr $pl[0], $+[0];
        if ($pl[0] =~ /^(_*)/) {
            $second_part .= $1;
            $pl[0] = substr $pl[0], $+[0];
        }
        if (isNumberNext()) {
            # assume safe to call (translating a number considers spacing)
            # "safe" because there is an e attached to suffix of our number
            $py_number .= $second_part . translateNumber(0);
        } else { # restore (no alterations to py_num)
            $pl[0] = $second_part . $pl[0];
        }
    }
    # remove underscores (can't use tr to replace with empty chars?)
    $py_number =~ s/_//g;
    # python3 prefix for an octal number is 0o or 0O
    $py_number =~ s/^(\D*)0/${1}0o/ if ($py_number =~ /^\D*0\d/);
    return $py_number . translateNextWhitespace();
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
    # "<=>" of string "cmp" (required in set 3?? or not??)
    return 1 if $pl[0] =~ /^(<=>|cmp[;\s()])(\s*)/;

    #   (set 3 requires eq, though never specified in any of the sets it
    #   was required to be implemented...)
    return 1 if $pl[0] =~ /^(eq|ne|gt|ge|lt|le)(\s*)/;

    # "||, ""&&", "<=", ">=, "!=", "==", "**", "<<", ">>"
    return 1 if $pl[0] =~ /^([|][|]|&&|<=|>=|!=|==|\*\*|>>|<<)(\s*)/;
    # "+", "-", "/", "%", "*", "!", "<", ">", "|", "^", "&", "~", "="
    return 1 if $pl[0] =~ /^([+\-\/%*!<>|^&~=])(\s*)/;
    return 0;
}
sub isOperatorCmpSoon {
    # checks if there is a "<=>" in the current line, within the same level of
    # bracketing
    # FIXME: breaks if it's stored inside a string
    # FIXME: merging "<=>" with "cmp" might be a bug in some cases...
    #   it's only not a bug if grouped correctly (but maybe it requires
    #   this grouping to be valid? need to check if time permits)
    # doesn't handle multiline
    return 0 if ($pl[0] !~ /(<=>|cmp[;\s()])/); # NOTE: DO NOT ANCHOR THIS
    # setup
    my $cur_string = $pl[0];
    my $bracket_level = 0; # start on 0 brackets
    my $found = 0;
    # can't recursively call translateLine(), doesn't match for "<=>"
    while (length($cur_string) > 0) {
        if ($cur_string =~ /^(<=>|cmp[;\s()])/ && $bracket_level == 0) {
            $found = 1;
            last;
        }
        if ($cur_string =~ /^=[^=>]/ || $cur_string =~ /^\.\./) {
            # note: seeing "=>" should be impossible
            # ignore if "<=>" after "=" assignment
            # or if after ".." (place that in higher priority (like perl))
            last;
        }
        if ($cur_string =~ /^\(/) { # perl strings are weaksauce
            ++$bracket_level;
        } elsif ($cur_string =~ /^\)/) {
            --$bracket_level;
        }
        # pop off current char, to setup next char
        $cur_string = substr $cur_string, 1;
    }
    return $found;
}
sub translateExpression {
    #my ($arg) = @_;
    #translateOperator($arg) . translateLine();
    return translateOperator() . translateLine();
    # this should be fine even though number captures + and - signs
    # the concern is just that they aren't captured in the first arg when
    # passed into "cmp" or ".."
}
sub translateOperator {
    # match and translate one operator
    # input: first arg now decrepit. TAKES NO ARGUMENTS.
    # WARNING: case "<=>" handles uniquely due to bracketing requirements
    # TODO: doesn't check with types
    # NOTE: "<=>" now handled in an external function
    die if !(isOperatorNext());
    die if ($pl[0] =~ /^(<=>|cmp[;\s()])/);
    # note that "1 <=> 2 <=> 3" is invalid perl (must be bracketed)

    #my ($first_arg) = @_;
    #$first_arg .= " " if ($first_arg !~ /\s$/);

    # first_arg is decrepit but we still might need spacing in front
    # todo: should format the spacing better (this always inserts an
    # extra front space for any operator not "<=>").
    my $first_arg = " ";
    my $py_line = "";
    my $next = " ";
    # check string operator: ($pl[0] updated after the if cases)
    # note: spec doesn't say to implement these but set 3 requires them??
    # (it requires at lease "eq" and maybe "ne")
    if ($pl[0] =~ /^(eq)(\s*)/) {
        $next = $2 if (defined $2 && $2 ne "");
        $py_line .= $first_arg . "==" . $next;
    }
    elsif ($pl[0] =~ /^(ne)(\s*)/) {
        $next = $2 if (defined $2 && $2 ne "");
        $py_line .= $first_arg . "!=" . $next;
    }
    elsif ($pl[0] =~ /^(gt)(\s*)/) {
        $next = $2 if (defined $2 && $2 ne "");
        $py_line .= $first_arg . ">" . $next;
    }
    elsif ($pl[0] =~ /^(ge)(\s*)/) {
        $next = $2 if (defined $2 && $2 ne "");
        $py_line .= $first_arg . ">=" . $next;
    }
    elsif ($pl[0] =~ /^(lt)(\s*)/) {
        $next = $2 if (defined $2 && $2 ne "");
        $py_line .= $first_arg . "<" . $next;
    }
    elsif ($pl[0] =~ /^(le)(\s*)/) {
        $next = $2 if (defined $2 && $2 ne "");
        $py_line .= $first_arg . "<=" . $next;
    }
    # implement numeric operators
    elsif ($pl[0] =~ /^([|][|])(\s*)/) {
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
    # remove remainder of match from above
    $pl[0] = substr $pl[0], $+[0];
    return $py_line . translateNextWhitespace();
}
sub translateOperatorCmp {
    # specifically for "<=>" operator because of its higher precedence in perl
    # input: first converted argument
    die if !(isOperatorNext() && isOperatorCmpSoon());
    my ($first_arg) = @_;
    # prevent future arguments in the same "line" comparing to same "<=>"
    my $prev_check_cmp = $check_cmp;
    $check_cmp = 0;
    my $py_line = "plpy_cmp(" . $first_arg . translateNextWhitespace();
    $py_custom_func_import{"plpy_cmp"} = 1; # add to set
    # grab expression until encountering "<=>"
    while ($pl[0] !~ /^(<=>|cmp)/) {
        $py_line .= translateExpression();
        #$check_cmp = 0;
        # theory: any nested "<=>" (must be within round brackets) will turn on
        # $check_cmp, so turn it back off again if you want to be defensive
    }
    # grab "<=>" and ignore
    $pl[0] =~ /^(<=>|cmp)(\s*)/; # should be ok? doesn't handle $_, etc.
    $py_line .= ",";
    $py_line .= $2 if defined $2;
    $pl[0] = substr $pl[0], $+[0];
    # grab expression until no more
    $py_line .= translateLine();
    while (isOperatorNext()) {
        $py_line .= translateExpression();
    }
    # restore global param
    $check_cmp = $prev_check_cmp;
    return $py_line . ")" . translateNextWhitespace();
}

sub translateOtherOperators {
    # used for translating remaining operators "..", "<=>", "cmp"
    # super badly structured code due to poor design from forgetting to
    # consider issues with arg formatting and function calls
    # (or is it supposed to be this hard?)
    my ($result) = @_;
    if (isOperatorDoubleDotSoon() && $check_double_dot && $check_cmp) {
        # note this gives ".." higher precedence to "<=>", which is
        # what we want (higher precedence by checking check_cmp)
        # [some disgusting code (checking if "<=>" in front of "..")]
        if (isOperatorNext() && isOperatorCmpSoon() && $check_cmp) {
            $result = translateOperatorCmp($result);
        }
        $result = translateOperatorDoubleDot($result);
    }
    # impossible to encounter ".." and then "cmp" immediately afterwards
    elsif (isOperatorNext() && isOperatorCmpSoon() && $check_cmp) {
        $result = translateOperatorCmp($result);
    }

    return $result;
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
    # no need to format if the line is whitespace only
    if ($pl[0] =~ /^(\s*)$/) {
        # this should just strip $pl[0] to an empty line
        $pl[0] = substr $pl[0], $+[0];
        return $1;
    }
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
    my $is_c_for_loop = 0;
    # brackets are non-optional in control flow?
    if ($command =~ /^(if|elsif|while)/) {
        # format command (only required by elsif)
        $command =~ s/s// if $command =~ /^elsif/;
        $py_line .= $command;
        # grab round brackets (assumes valid perl)
        # ... python doesn't need brackets, but it won't break with them
        $pl[0] =~ /^(\s*\()/;
        $py_line .= $1;
        $pl[0] = substr $pl[0], $+[0];
        # note possible for no argument: for infinite "while" loops
        if ($pl[0] =~ /^(\s*\))/) {
            # python can't accept this: it must have an arg
            $py_line .= "1";
        } else {
            # args exist, so grab one arg (can be expression)
            $py_line .= translateLine(); # whitespace already grabbed
            while (isOperatorNext()) { # assume "<=>" handled by translateLine
                $py_line .= translateExpression();
            }
        }
        # close round brackets
        $pl[0] =~ /^(\s*\))/;
        $py_line .= $1 . ":";
        $pl[0] = substr $pl[0], $+[0];
        # [HACK]: hardcoded special case of reading from stdin
        # (not sure how else i could resolve this)
        #   safe to assume that "while($... = <STDIN>)" has no other args
        #   within the 1 level bracket containing "= <STDIN>"
        #   because otherwise it would give perl warnings?
        #   below: compare to PYTHON code
        if ($py_line =~ /while\s*\((.*[^=])=\s*sys\.stdin\.readline/) {
            $py_line = "for $1 in sys.stdin:";
            # hardcode it in; have to reformat the whole line since
            # python can't support assignment within brackets
            #   ie hardcoded mix to mistranslation (especially with
            #   the conversion of ..stdin.readline to just stdin)
        }

    }
    elsif ($command =~ /^(else)/) {
        $py_line .= $command . ":"; # else doesn't have arguments
    }
    elsif ($command =~ /^(for)/ && $pl[0] =~ /\(.*?;.*?;.*?\)/) {
        # NOTE: both "for" and "foreach" work
        # convert this to a while loop since c-style for not in python
        # grab round brackets (and spacing afterwards)
        $is_c_for_loop = 1;
        $pl[0] =~ /^(\s*\(\s*)/;
        my $cust_header = "while" . $1;
        $pl[0] = substr $pl[0], $+[0];
        # grab three args (";" separated)
        #
        # note: each of the "three args" could have subargs "," separated...
        # note: translateLine() now updated to be able to grab in-line,
        # intermediate ";" (but leave below as is for now (old legacy code))
        my $initial_args = join(";",translateFuncArgs()) . "\n";
        $pl[0] = substr $pl[0], $+[0] if ($pl[0] =~ /^(\s*;\s*)/);
        # don't put in the ";" just to stay consistent, too annoying to deal with
        # if empty, leaves a "\n" (important, it is useful)
        # NOTE: DON'T NEED THE ";" TO BE VALID PYTHON

        my $condition_args = join(" or ",translateFuncArgs()); # lazy spacing
        $pl[0] = substr $pl[0], $+[0] if ($pl[0] =~ /^(\s*;\s*)/);
        # if empty, insert a "1"

        if (!defined($condition_args) || $condition_args eq "") {
            $condition_args = "1";
        }

        my $increment_args = join(";",translateFuncArgs()) . "\n";
        $pl[0] = substr $pl[0], $+[0] if ($pl[0] =~ /^(\s*;\s*)/);
        # if empty, leaves a "\n"
        # NOTE: DON'T NEED THE ";" TO BE VALID PYTHON

        # close round brackets
        $pl[0] =~ /^(\s*\))/;
        $cust_header .= $condition_args . $1 . ":";
        $pl[0] = substr $pl[0], $+[0];

        # begin formatting the while loop (cust_header already formatted)
        $py_line .= $initial_args . (leadingWhitespace() x $n_indents);
        $py_line .= $cust_header; # ready to grab braces
        # grab it here since increment_args will be out of scope outside the "if"
        $py_line .= translateBraces($increment_args);
    }
    elsif ($command =~ /^(for)/) {
        # not a c-style for loop (lower precedence)
        # note: can't enclose entire python argument in brackets
        $py_line = "for" . translateNextWhitespace();
        $py_line .= " " if $py_line eq "for";
        # grab one arg (shouldn't be expression)
        $py_line .= translateLine(); # whitespace already grabbed
        while (isOperatorNext()) { # assume "<=>" handled by translateLine
            # (foreach shouldn't have an expression here)
            # but we are being defensive anyway
            $py_line .= translateExpression();
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
    } else {
        die;
    }
    # grab contents (except if "for" loop, which grabbed it earlier)
    $py_line .= translateBraces("") if !($is_c_for_loop);
    # throwaway next whitespace if "}" is followed by "elsif" or "else"
    my $after_braces = translateNextWhitespace();
    if ($pl[0] =~ /^\s*elsif|else/) {
        return $py_line; # throw away the whitespaces (SPECIAL CASE)
        # consider: "} elsif ...", whitespace is not an issue due to this
        # if statement
        # consider: "} \n  elsif ...", whitespace after braces left on the
        # line above, and whitespace before elsif modified by
        # Leading Whitespace, hence it works.
    }
    return $py_line . $after_braces;
}

sub translateBraces {
    # starts scanning from beginning of "{" to end of "}"
    # grab everything within pair of "{", "}", excluding braces
    # input: end arguments to be inserted before closing the loop
    # defensive check implemented below inside the first while loop
    my ($end_inserts) = @_;
    my $py_line = "";
    # find braces (could be on new line)
    while ($pl[0] !~ /^(\s*)\{/) {
        if (!defined($pl[0]) || $pl[0] eq "" || $pl[0] =~ /^\s*$/) {
            # ignore the whitespace (can't be dangerous)
            shift @pl;
            my $lead_ws = translateLeadingWhitespace();
            $pl[0] = $lead_ws . $pl[0];
        } else {
            # for some reason there is something else before the braces
            # (kept for legacy purposes only)
            # TODO later: (take out if you can qualify it to be useless)
            $py_line .= translateLine();
        }
        die if (scalar @pl == 0);   # something went wrong
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
    # intermediate insertion of end args (indentation correct already because
    # we overinsert too much leading whitespace before hitting "}")
    if ($end_inserts ne "") {
        $py_line .= $end_inserts . (leadingWhitespace() x $n_indents);
    }
    $pl[0] =~ /^([;\s]*)\}/;
    # restore indent count on exiting "}", and update $pl[0]
    --$n_indents;
    $pl[0] = substr $pl[0], $+[0]; # ignore braces
    # for later: add back in the ";" for sake of neatness
    my $captured_semicol = 0;
    $captured_semicol = 1 if ($1 =~ /;/); # NOTE: DO NOT ANCHOR THIS
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
sub translateChomp {
    # implements simplest version of chomp (to one variable)
    # and assumes $/ eq "\n" (test code can't change it anyway)
    #   ie only rstrips away newlines, NOT OTHER WHITESPACE
    #   this is similar to how perl works
    # TODO: implement $_ and all the other missing functionality, etc.
    die if $pl[0] !~ /^(chomp)[(;\s]/;
    $pl[0] = substr $pl[0], $+[1];
    translateNextWhitespace(); # throw away the whitespace
    my $is_bracketed = 0;
    # grab and remove bracket, if any
    if ($pl[0] =~ /^\(/) {
        $is_bracketed = 1;
        $pl[0] = substr $pl[0], 1;
        translateNextWhitespace(); # throw away the whitespace
    }
    # get 1 arg (chomp arg should be a variable)
    my $arg = translateLine();
    # todo: doesn't consider what "$/" is
    my $py_line = $arg . " = " . $arg . ".rstrip('\\n')";
    # close bracket, if any
    if ($is_bracketed && $pl[0] =~ /^\)/) {
        $pl[0] = substr $pl[0], 1;
    }
    return $py_line . translateNextWhitespace();
}

sub translateExit {
    # implements exit
    die if $pl[0] !~ /^(exit)[(;\s]/;
    $pl[0] = substr $pl[0], $+[1];
    translateNextWhitespace(); # throw away the whitespace
    my $is_bracketed = 0;
    # grab and remove bracket, if any
    if ($pl[0] =~ /^\(/) {
        $is_bracketed = 1;
        $pl[0] = substr $pl[0], 1;
        translateNextWhitespace(); # throw away the whitespace
    }
    # get 1 arg (... doesn't handle for $_)
    my $arg = translateLine();
    while (isOperatorNext()) { # ... might be an expression
        $arg .= translateExpression();
    }
    # close bracket, if any
    if ($is_bracketed && $pl[0] =~ /^\)/) {
        $pl[0] = substr $pl[0], 1;
    }
    $py_module_import{"sys"} = 1;
    # not sure if int() typecasting desired?
    # python sys.exit more general than perl's, so desireable?
    # (suppresses output since non-integer gets outputted)??
    # ... hope and pray that no weird exit calls are made
    my $py_line = "sys.exit(int($arg))";
    return $py_line . translateNextWhitespace();
}

# repeated code structures to "isOperatorCmpSoon", etc.
# (very short term): easier to duplicate code than to rework existing code
# especially if you wanted to later handle all the weirder cases of ".."
# since range() barely covers for it
#
# FIXME: breaks if it's stored inside a string
# (fix by storing original contents; if you never find ".." inside then exit
# with the original contents?)
# ^ actually you don't need to fix this bug because it would have to be for
# a non-numeric case, which your code doesn't handle in the first place
sub isOperatorDoubleDotSoon {
    return 0 if ($pl[0] !~ /(\.\.)/); # NOTE: DO NOT ANCHOR THIS
    # setup
    my $cur_string = $pl[0];
    my $bracket_level = 0; # start on 0 brackets
    my $found = 0;
    # can't recursively call translateLine(), doesn't match for ".."
    while (length($cur_string) > 0) {
        if ($cur_string =~ /^(\.\.)/ && $bracket_level == 0) {
            $found = 1;
            last;
        }
        if ($cur_string =~ /^=[^=>]/) {
            # ignore if ".." after "=" assignment
            last;
        }
        if ($cur_string =~ /^\(/) { # perl strings are weaksauce
            ++$bracket_level;
        } elsif ($cur_string =~ /^\)/) {
            --$bracket_level;
        }
        # pop off current char, to setup next char
        $cur_string = substr $cur_string, 1;
    }
    return $found;
}
sub translateOperatorDoubleDot {
    # match to "..", has higher precedence to other operators just like "<=>"
    # input: first converted argument
    # todo: maybe you can assume that only one ".." exists per line? investigate
    die if $pl[0] !~ /\.\./; # NOTE: DO NOT ANCHOR THIS?
    my ($first_arg) = @_;
    # prevent future arguments in the same "line" comparing to same "<=>"
    my $prev_check_double_dot = $check_double_dot;
    $check_double_dot = 0;
    # FIXME: does some sketchy, probably unsafe, typecasting
    my $py_line = "list(range(int(" . $first_arg . translateNextWhitespace();
    # nothing to import such that: $py_custom_func_import{""} = 1;
    # grab expression until encountering ".."
    while ($pl[0] !~ /^(\.\.)/) {
        $py_line .= translateLine();
    }
    # grab ".." and ignore
    $pl[0] =~ /^(\.\.)(\s*)/; # should be ok? doesn't handle $_, etc.
    $py_line .= "), int("; # close int()
    $py_line .= $2 if defined $2;
    $pl[0] = substr $pl[0], $+[0];
    # grab expression until no more
    $py_line .= translateLine();
    while (isOperatorNext()) {
        $py_line .= translateExpression();
    }
    # since range is right hand exclusive...
    # (fix spacing if you want (if you have time))
    $py_line .= " + 1";
    # restore global param
    $check_double_dot = $prev_check_double_dot;
    $py_line .= ")))" . translateNextWhitespace();
    return $py_line;
}

sub translateArray {
    # match to an array call (not an array element call)
    # NOTE: arrays not handled in print "@.." statements
    die if !($pl[0] =~ /^\@\s*(\w+)/ || $pl[0] =~ /^\@\s*\{\s*(\w+)\s*\}/);
    # only handles ARGV right now (ie so no initialisation of empty arrays
    # necessary)
    my $py_line = "";              # no spacing
    my $array_name = $1;
    $pl[0] = substr $pl[0], $+[0];
    if ($array_name eq "ARGV") {    # case matters
        $py_module_import{"sys"} = 1;
        $py_line .= "sys.argv"; # newline already thrown away
    } else {
        $py_array_define{$array_name} = 1;
        # (below code for predefining the array, but it's too difficult
        # to do?)
        #
        #if (!defined($py_array_define{$array_name})) {
        #    $py_array_define{$array_name} = 1;
            # assume a reassignment will probably happen somewhere
            # after the initial declaration
        #}
        $py_line .= $array_name;
    }
    $py_line .= " ";                # also lazy
    return $py_line . translateNextWhitespace();
}

sub translateArrayElement {
    # grab array element "name[...]"
    # it might handle multidimensional arrays
    die if !($pl[0] =~ /^\$\s*(\w+)\s*\[\s*(.*?)\s*\]/ ||
            $pl[0] =~ /^\$\s*\{\s*(\w+)\s*\[\s*(.*?)\s*\]\s*\}/);
    # match and format (pretty much the same code)
    # note: we can only grab the initial header portion since need to match
    # an expression afterwards
    my $array_name;
    my $saw_braces = 0;
    if ($pl[0] =~ /^\$\s*\{\s*(\w+)\s*\[\s*/) {
        $saw_braces = 1;
        $array_name = $1;
        $pl[0] = substr $pl[0], $+[0];
    }
    elsif ($pl[0] =~ /^\$\s*(\w+)\s*\[\s*/) {
        $array_name = $1;
        $pl[0] = substr $pl[0], $+[0];
    }
    # grab expression
    my $index = translateLine();
    while (isOperatorNext()) {
        $index .= translateExpression();
    }
    # special cases
    if ($array_name eq "ARGV") {    # case matters
        $py_module_import{"sys"} = 1;
        $array_name = "sys.argv";
        # throw away the filename
        #$index .= " + 1"; # NOTE: resolved way way above in a better way
    } else {
        $py_array_define{$array_name} = 1;
    }
    # grab "]", and maybe "}"
    if ($pl[0] =~ /\s*\]/) {
        $pl[0] = substr $pl[0], $+[0];
    }
    if ($saw_braces && $pl[0] =~ /\s*\}/) {
        $pl[0] = substr $pl[0], $+[0];
    }
    # format answer (lazy spacing)
    my $py_line = $array_name . "[$index] ";
    return $py_line . translateNextWhitespace();
}

sub translateJoin {
    die if $pl[0] !~ /^(join)[(;\s]/;
    $pl[0] = substr $pl[0], $+[1];
    translateNextWhitespace(); # throw away the whitespace
    my $is_bracketed = 0;
    # grab and remove bracket, if any
    if ($pl[0] =~ /^\(/) {
        $is_bracketed = 1;
        $pl[0] = substr $pl[0], 1;
        translateNextWhitespace(); # throw away the whitespace
    }
    # get 2 args
    my @args = translateFuncArgs();
    die if scalar(@args) < 2; # $_ implementation not handled
    my $separator = shift @args; # hope it is a string
    my $remaining = join(",", @args);
    # format args
    my $py_line;
    if ($remaining =~ /,/) { # DO NOT ANCHOR THIS
        # remaining is a list of strings, so need to group as a list
        # using "[]" or as a tuple using "()" (doesn't really matter)
        $py_line = $separator . "." . "join([$remaining])";
    } else {
        # doesn't really make a difference though?
        $py_line = $separator . "." . "join($remaining)";
    }
    # close bracket, if any
    if ($is_bracketed && $pl[0] =~ /^\)/) {
        $pl[0] = substr $pl[0], 1;
    }
    return $py_line . translateNextWhitespace();
}

sub translateSplit {
    die if $pl[0] !~ /^(split)[(;\s]/;
    $pl[0] = substr $pl[0], $+[1];
    translateNextWhitespace(); # throw away the whitespace
    my $is_bracketed = 0;
    # grab and remove bracket, if any
    if ($pl[0] =~ /^\(/) {
        $is_bracketed = 1;
        $pl[0] = substr $pl[0], 1;
        translateNextWhitespace(); # throw away the whitespace
    }
    # get 2 args (TODO: this is only a very simple implementation)
    my @args = translateFuncArgs();
    die if scalar(@args) < 2; # $_ implementation not handled
    # hope only 2 args (otherwise, data loss)
    my $separator = shift @args; # hope it is a string (can't handle regex)
    my $remaining = shift @args; # hope it is a string / variable
    # format args
    my $py_line = $remaining . "." . "split($separator)";
    # close bracket, if any
    if ($is_bracketed && $pl[0] =~ /^\)/) {
        $pl[0] = substr $pl[0], 1;
    }
    return $py_line . translateNextWhitespace();
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
     print "pl[0]:","'",$pl[0],"'\n";
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

# note: should have just read this instead: (too late now)
# http://cpansearch.perl.org/src/NWCLARK/perl-5.8.8/perly.y
