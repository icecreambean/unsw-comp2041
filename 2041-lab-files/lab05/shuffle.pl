#!/usr/bin/perl
use warnings;   # pragma: isolate warnings to certain areas
use strict;

my @line_list = ();     # my: declares local var
while (my $line = <STDIN>) {
    push(@line_list, $line);
}
for (my $i = 0; $i < @line_list; $i++) {
    # grab two random indexes and swap contents
    my $ind_1 = rand(scalar @line_list);
    my $ind_2 = rand(scalar @line_list);
    # fractional components get truncated off
    # but, if need to force int, use: int()
    my $temp = $line_list[$ind_1];
    $line_list[$ind_1] = $line_list[$ind_2];
    $line_list[$ind_2] = $temp;
}
print(@line_list);
