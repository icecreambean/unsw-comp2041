#!/usr/bin/perl -w
die "Usage: [course_code]" if scalar @ARGV < 1;
foreach $code (@ARGV) {
    open(F, "wget -q -O- http://timetable.unsw.edu.au/current/$code.html | ") or die "$?";
    my $read_info = 0;  # false;
    my $skip_lines = 5;
    my $count = 0;
    my %output_lines;   # set of sets
    my $sem;            # gets reset by 'Lecture' regex
    while ($line = <F>) {
        # start of lecture block
        if ($line =~ /<td class.*>Lecture<\/a><\/td>/) {
            ($sem) = $line =~ /#([A-Z]\d)/;  # brackets for arrays, i.e. ($sem)
            $output_lines{$code} = $sem;
            $read_info = 1;
            next;
        }
        next if (!($read_info));    # only read the code in the lecture block
        if ($count < $skip_lines) {         # lines to skip after reading semester no.
            $count++;
            next;
        }
        # grab lecture times and assume nothing after for this block
        my ($descrip) = $line =~ /<td class.*>(.*)<\/td>/;
        # empty $descrip -> regex failed, this block not in correct format
        if (!($descrip eq "")) {
            # put in set (hash) in case of duplication
            $output_lines{$code}{$sem}{$descrip} = 1;
        }
        # reset stuff
        $read_info = 0;
        $count = 0;
        $output = "";
    }
    # print stuff (note: key order is unpredictable (ALWAYS sort))
    foreach $code (sort keys %output_lines) {
        foreach $sem (sort keys %{$output_lines{$code}}) {
            foreach $descrip (sort keys %{$output_lines{$code}{$sem}}) {
                print "$code: $sem $descrip\n";
            }
        }
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
