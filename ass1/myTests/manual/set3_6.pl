#!/usr/bin/perl -w

print @ARGV, "\n";

foreach $arg (  @   {   ARGV   }   ) {
    print "$arg\n";
}
print "${ARGV[1]}\n";
print $ARGV[1],"\n";
