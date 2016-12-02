#!/usr/bin/perl -w
# put your demo script here

# taken from: /home/cs2041//public_html/16s2/code/perl/snap_consecutive.pl
#   Reads lines of input until end-of-input
#   Print snap! if two consecutive lines are identical

print "Enter line: ";
$last_line = <STDIN>;
print "Enter line: ";
while ($line = <STDIN>) {
	if ($line eq $last_line) {
		print "Snap!\n";
	}
    $last_line = $line;
	print "Enter line: ";
}
