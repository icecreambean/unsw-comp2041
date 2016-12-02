#!/usr/bin/perl -w

while ($line = <STDIN>) {
    @all_words = split /[^a-z]+/i, $line;
    foreach $word (@all_words) {
        $count++ if $word =~ /[a-z]/i;
    }
}
print $count, " words\n";



# (from inside the while loop:)
#print join ",", @all_words, "\n";         # debug
#print "size: ", scalar @all_words, "\n";
#$count += scalar @all_words;
# [doesn't work]: would need to remove all empty strings from list
