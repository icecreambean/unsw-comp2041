sub translateBraces {
    # grab everything within pair of "{", "}", braces INCLUSIVE
    # WARNING: inconsistent implementation to translateFuncArgs?
    # WARNING: no defensive check implemented...
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
