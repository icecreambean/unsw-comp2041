# grab contents (except if "for" loop, which grabbed it earlier)
$py_line .= translateBraces("") if !($is_c_for_loop);

# check if next thing after braces is "elsif / else"
my $lines_dropped = 0; # boolean
while (!defined($pl[0]) || $pl[0] eq "" || $pl[0] =~ /^(\s*)$/) {
    # throwaway empty lines (lazy approach)
    shift(@pl);
    $lines_dropped = 1;
}
# throwaway next whitespace if "}" is followed by "elsif" or "else"
if ($pl[0] =~ /^\s*elsif|else/) {
    # throw away the whitespaces (SPECIAL CASE)
    translateLeadingWhitespace();
}
elsif ($lines_dropped) {
    # we are on some new line
    $py_line .= translateLeadingWhitespace();
} else {
    $py_line .= " "; # lazy
}
return $py_line;
