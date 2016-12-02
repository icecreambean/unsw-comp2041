#!/usr/bin/perl -w
$recursion_on = 0;    # initially false
$course_code = "DELL1234"; # some random default
#$course_code = $ARGV[0];
# get input
foreach $arg (@ARGV) {
    if ($arg =~ /^-/) {
        if ($arg =~ /r/) {
            $recursion_on = 1;
        }
    } elsif ($arg =~ /[A-Z]{4}\d{4}/) {
        $course_code = $arg;
    }
}

# bash: -O to output to file, '-' afterwards indicates stdout
$under_wb = "http://www.handbook.unsw.edu.au/undergraduate/courses/2015/";
$post_wb = "http://www.handbook.unsw.edu.au/postgraduate/courses/2015/";

my %all_codes;
GetPrereqs($course_code);

# sorted alphabetically by lowercase-only comparison
foreach $code (sort ({lc($a) cmp lc($b)} keys %all_codes)) {
    print "$code\n";
}

#####################################

sub GetPrereqs {
    # access array args using @_
    # scalar(@_) gives total num args passed in
    # crude assert checking
    die "incorrect GetPrereqs(<code>) usage" if (scalar(@_) != 1);
    my $cur_code = $_[0];
    my $start_read = 0;  # false
    foreach my $option (($under_wb, $post_wb)) {
        open(F, "wget -q -O- $option$cur_code.html |") or die;
        foreach my $line (<F>) {
            # no post-fix conditional else
            # (!~ is the negation of =~) ((...) == false also works)
            # NOTE: include co-requisites
            # NOTE: ELEC2141 page, inconsistent course code formats
            # NOTE: MTRN3500 pre-req header title format
            # NOTE: COMP1917 has trap pre-req in description
            # check out COMP2121...
            #next if ($line !~ /[Rr]equisites?:? [A-Z]?/); # has false positives
            if ($line =~ /[Ee]nrolment [Rr]equirements:/) {
                $start_read = 1;
                next;
            }
            $start_read = 0 if ($line =~ /[Dd]escription/);
            next if $start_read == 0;
            next if ($line !~ /[Rr]equisite|[Pp]re:/);

            chomp $line;
            $line =~ s/.*([Rr]equisites?:?|[Pp]re:) (.+?)<\/p>.*/$2/;
            foreach my $word (split / /, $line) {
                # tr doesn't recognise \s?
                # hacky, ugly way to do it?
                if ($word =~ s/.*([A-Za-z]{4}\d{4}).*/$1/) {
                    $word = uc($word);  # convert to uppercase only
                    #print "$word from $cur_code\n";
                    if (not(exists $all_codes{$word})) {
                        $all_codes{$word} = 1;
                        GetPrereqs($word) if $recursion_on;
                    }
                    # unnecessary to set to 1 if duplicate
                }
            }
        }
    }
}

# negation: if( not(...) )
# my = an actual local var.
# local = borrows a global var and restores it later
