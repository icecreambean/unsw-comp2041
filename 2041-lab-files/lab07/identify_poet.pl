#!/usr/bin/perl
use warnings;
use strict;

die "usage: <1 or more files>" if scalar @ARGV < 1;

# (actually, a hash isn't necessarily to do this...)
# build hash (works)
our %poet_word_freq; # global
foreach my $fn (glob("poems/*.txt")) {
    extract_word_freq($fn);
}
# compute log freq, etc.
foreach my $fn (@ARGV) {
    # get set of ALL words in fn (note NOT ONLY UNIQUE words)
    #   DECREPIT: there are better ways of doing this
    open(F, "<", "$fn") or die "$!";
    #my %fn_word_set;        # could be made into its own function
    my @fn_word_set;        # not actually a set anymore
    while (my $line = <F>) {
        $line = lc $line;
        my @all_words = split /[^a-z]+/, $line;
        foreach my $word (@all_words) {
            #$fn_word_set{$word} = 1 if $word =~ /[a-z]/;
            push @fn_word_set, $word if $word =~ /[a-z]/;
        }
    }
    close(F);

    # extract author with largest log-prob
    my $best_author = "";    # placeholder vals
    my $best_log_prob = 0;
    foreach my $author (keys %poet_word_freq) {
        my $cur_log_prob = 0;
        # log-prob of each word from the file, for this author
        foreach my $word (@fn_word_set) { #(keys %fn_word_set) {
            my $freq = $poet_word_freq{$author}{$word};
            $freq = 0 if (!$freq);
            my $total = total_words($author);
            my $log_freq = log(($freq+1)/$total);
            $cur_log_prob += $log_freq;
        }
        # check if largest log-prob => best option
        if ($best_author eq "" || $best_log_prob < $cur_log_prob) {
            $best_author = $author;
            $best_log_prob = $cur_log_prob;
        }
    }
    # print answer for this file
    printf("%s most resembles the work of %s (log-probability=%.1f)\n",
    $fn, $best_author, $best_log_prob);
}


######################################
# could return a hash or a hash reference (there are ptrs in Perl...)

sub extract_word_freq { # tested: works (beware if 0 valued - undef'd)
    # writes to global hash %poet_word_freq
    die "extract_word_freq(FILENAME): incorrect num args" if scalar @_ != 1;
    my $fn = $_[0];
    open(F, "<", "$fn") or die "$!";
    # get author's name
    $fn =~ /poems\/(.*)\.[^.]*$/;
    my $author = $1;
    $author =~ tr/_/ /;
    # extract word count to dict
    while (my $line = <F>) {
        $line = lc $line;   # explicitly do because hashing
        my @all_words = split /[^a-z]+/, $line;
        foreach my $word (@all_words) {
            $poet_word_freq{$author}{$word}++ if $word =~ /[a-z]/i;
        }
    }
    close(F);
}

sub total_words { # tested: works
    # computed from hash
    die "total_words(AUTHOR_NAME): incorrect num args" if scalar @_ != 1;
    my $author = $_[0];
    my $count = 0;
    for my $word (keys %{$poet_word_freq{$author}}) {
        $count += $poet_word_freq{$author}{$word};
    }
    return $count;
}

######################################

sub count_word { # unused, oops
    die "count_word(WORD, FILENAME): incorrect num args" if scalar @_!= 2;
    # args: search_word, file_name
    my $word = lc $_[0];
    open(F, "<", "$_[1]") or die "$!";
    my $count = 0;
    while (my $line = <F>) {
        my @remaining = split /\b$word\b/i, $line;
        $count += scalar @remaining -1;
    }
    close(F);
    return $count;
}
