# PRINT STUFF
if ($string =~ /\\n$/) {
    # newline at end of string, remove it for 'pythonic' code
    $string = substr($string, 0, scalar $string -2);
    push @python_code, "print(\"$string\")";
} else { # no newline at end of string
    push @python_code, "print(\"$string\", end='')";
}
