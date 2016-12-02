#!/usr/bin/perl
use strict;
use warnings;
die "Usage: {-d} [course_code]" if scalar @ARGV < 1;
my $d_flag = 0;
my $t_flag = 0;
if ($ARGV[0] eq "-d") {
    $d_flag = 1;
    shift @ARGV;
} elsif ($ARGV[0] eq "-t") {
    $t_flag = 1;
    shift @ARGV;
}

# hacked on -t option
my %all_hourly_by_sem;
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
    my %hourly_outputs_h; # set
    my @hourly_outputs_a; # actual order of input
    foreach my $line (@output_lines_ordered) {
        if (!($d_flag || $t_flag)) {
            print "$line\n";
            next;
        }
        my @words = split " ", $line;
        my $sem = $words[1];
        # extract each "{days} start - end" from string
        foreach my $slot ($line =~ / (\w{3}.*?\d{2}:\d{2} - \d{2}:\d{2})/g) {
            # no brackets here to enclose $var...
            $slot =~ s/-//;     # tr doesn't work!!! (for , or for -)
            # each day is comma separated
            my ($days_string, $time_string) = $slot =~ /(.*?)(\d.*)$/;
            my @days = split ",", $days_string;
            # each day will share the same hours
            my ($start, $end) = split " ", $time_string;
            # strip leading 0s, leading whitespace
            $start =~ s/^\s*0*//;
            $end =~ s/^\s*0*//;
            # extract just the hour
            # (need to be careful if lecture to half hour time): e.g. COMP4121
            $start =~ s/:.*$//;     # note: can't insert var into s///?
            my $end_fix_val = 0;   # 0 if aligned to hour, 1 otherwise
            $end_fix_val = 1 if !($end =~/:00/);
            $end =~ s/:.*$//;
            $end += $end_fix_val;
            # loop for each $day
            foreach my $day (@days) {
                # strip whitespace from the element pulled from @days
                $day =~ s/^\s*//;
                $day =~ s/\s*$//;
                my $count = $start;
                while ($count < $end) {
                    my $hour_out = "$sem $code $day $count";
                    # more duplicate output issues to resolve
                    if (!(defined $hourly_outputs_h{$hour_out})) {
                        push @hourly_outputs_a, $hour_out;
                        # hacked on -t option (curHour == count)
                        $all_hourly_by_sem{$sem}{$day}{$count}++;
                    }
                    $hourly_outputs_h{$hour_out} = 1;
                    $count++;
                }
            }
        }
    }
    # write output from @hourly_outputs_a
    if ($d_flag) {
        foreach my $line (@hourly_outputs_a) {
            print "$line\n";
        }
    }
}
if ($t_flag) {
    # format: $all_hourly_by_sem{$sem}{$day}{$hour}
    foreach my $sem ('S1','S2','X1') {
        next if (!(defined $all_hourly_by_sem{$sem}));
        my @days = ('Mon', 'Tue', 'Wed', 'Thu', 'Fri');
        # header (generalised)
        print "$sem    ";
        foreach my $day (@days) {
            print "   $day";
        }
        print "\n";
        #print "$sem       Mon   Tue   Wed   Thu   Fri\n";
        # each row
        my $start = 9;
        my $end = 20;   # inclusive
        my $cur_time = $start;
        while ($cur_time <= $end) {
            # formatted string
            my $format_time = $cur_time;
            $format_time = "0$cur_time" if $cur_time < 10;
            $format_time .= ":00";
            # each day
            my @lecs_on_day = ();
            my $last_day_index = -1;    # -1 for 'invalid'
            my $count = 0;
            foreach my $day (@days) {
                if (defined $all_hourly_by_sem{$sem}{$day}{$cur_time}) {
                    push @lecs_on_day, $all_hourly_by_sem{$sem}{$day}{$cur_time};
                    $last_day_index = $count;
                } else {
                    push @lecs_on_day, 0;
                }
                $count++;
            }
            # print out table row
            print $format_time;
            $count = 0;
            while ($count <= $last_day_index) {
                print "     ";
                if ($lecs_on_day[$count]) {
                    print $lecs_on_day[$count]
                } else {
                    print " ";
                }
                $count++;
            }
            print "\n";
            $cur_time++;
        }
    }
}


# COMP1927: X1 Wed, Fri 09:00 - 12:00 (Weeks:1-8)
# COMP2041: S2 Tue 13:00 - 15:00 (Weeks:1-9,10-12), Thu 17:00 - 18:00 (Weeks:1-9,10-12)
