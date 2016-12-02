#!/usr/bin/perl -w

# error message formatting
#$0 =~ s/^.\///;     # strip "./" from filename (don't need this)

$n = 10;
# num el ARGV > 0 and check is flag
if (@ARGV && $ARGV[0] =~ /^-[0-9]+$/) {
    $n = -$ARGV[0];
}

# extract filenames from command line args
# (i.e. filter out flags)
@files = ();
foreach $arg (@ARGV) {
    if ($arg eq "--version") {
        print "$0: version 0.1\n";
        exit(0);
    }
    if (!($arg =~ /^-.*/)) {
        push @files, $arg;
    }
}

# if no files in command args
if (@files == 0) {
    # read from standard input (e.g. piped in)
    # display last n lines of standard input
    # note: pipes (e.g. stdin) are not seekable
    @stdin_lines = ();
    while ($line = <STDIN>) {
        push @stdin_lines, $line;
    }
    $start_line = @stdin_lines - $n;
    for ($line_count = 0; $line_count < @stdin_lines; $line_count++) {
        if ($line_count >= $start_line) {    # note: 0 index'd
            print "$stdin_lines[$line_count]";
        }
    }
    exit 0;
}

foreach $f (@files) {
    open(F,"<$f") or die "$0: can't open $f\n";
    # separate files by title if more than one
    if (@files > 1) {
        print "==> $f <==\n";
    }
    # display last n lines of each file
    #@file_lines = ();    # assign to empty list. ALT: undef @array;
    $line_count = 0;
    while ($line = <F>) {     # more space efficient than for loop
        $line_count++;
    }
    # display last n lines of standard input
    seek(F, 0, 0);
    $start_line = $line_count - $n;
    #if ($start_line - $n < 0) {        # not needed
    #    $start_line = 0;
    #}
    $line_count = 0;        # note: counting from 0 index
    while ($line = <F>) {
        if ($line_count >= $start_line) {   # because 0 index'd
            print "$line";
        }
        $line_count++;
    }
    close(F);
}

# open each file
#foreach $f
