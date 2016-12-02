#!/usr/bin/perl
use warnings;
use strict;

die "usage: <search_word>" if scalar @ARGV != 1;
my $search_word = $ARGV[0];

foreach my $fn (glob("poems/*.txt")) {
    my $n_words = count_word($search_word, $fn);
    my $total = total_words($fn);
    my $freq = $n_words/$total;
    $fn =~ /poems\/(.*)\.[^.]*$/;
    my $author = $1;
    $author =~ tr/_/ /;
    printf("%4d/%6d = %.9f %s\n", $n_words, $total, $freq, $author);
}


sub total_words {
    die "total_words(FILENAME): incorrect num args" if scalar @_ != 1;
    open(F, "<", "$_[0]") or die "$!";
    my $count = 0;
    while (my $line = <F>) {
        my @all_words = split /[^a-z]+/i, $line;
        foreach my $word (@all_words) {
            $count++ if $word =~ /[a-z]/i;
        }
    }
    close(F);
    return $count;
}

sub count_word {
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
