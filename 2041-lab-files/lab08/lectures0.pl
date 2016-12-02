#!/usr/bin/perl
use strict;
use warnings;
die "Usage: [course_code]" if scalar @ARGV < 1;
foreach my $code (@ARGV) {
    open(F, "wget -q -O- http://timetable.unsw.edu.au/current/$code.html | ") or die "$?";
    my $read_info = 0;  # false;
    my $skip_lines = 5;
    my $count = 0;
    my $output = "";
    my %output_lines;
    my @output_lines_ordered;
    while (my $line = <F>) {
        # start of lecture block
        if ($line =~ /<td class.*>Lecture<\/a><\/td>/) {
            my ($sem) = $line =~ /#([A-Z]\d)/;  # brackets for arrays, i.e. ($sem)
            $output .= "$code: $sem";
            $read_info = 1;
            next;
        }
        next if (!($read_info));    # only read the code in the lecture block
        if ($count < $skip_lines) {          # lines to skip after reading semester no.
            $count++;
            next;
        }
        # grab lecture times and assume nothing after for this block
        my ($descrip) = $line =~ /<td class.*>(.*)<\/td>/;
        # empty $descrip -> regex failed, this block not in correct format
        if (!($descrip eq "")) {
            $output .= " $descrip";
            push @output_lines_ordered, $output if !(defined $output_lines{$output});
            # put in set (hash) as a lazy check for duplication
            $output_lines{$output} = 1;
            #print $output, "\n";
        }
        # reset stuff
        $read_info = 0;
        $count = 0;
        $output = "";
    }
    # print stuff
    foreach my $line (@output_lines_ordered) {
        print "$line\n";
    }
}



# [COMP2041]
#<td class="data"><a href="#S2-2022">Lecture</a></td>
#<td class="data"><a href="#S2-2022">T2</a></td>
#<td class="data"><a href="#S2-2022">2022</a></td>
#<td class="data"><a href="#S2-2022">1UGA</a></td>
#<td class="data"><font color="green">Open</font></td>
#<td class="data">239/245*</td>
#<td class="data">Tue 13:00 - 15:00 (Weeks:1-9,10-12), Thu 17:00 - 18:00 (Weeks:1-9,10-12)</td>
#</tr>
