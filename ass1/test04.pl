#!/usr/bin/perl -w
# put your demo script here
$b = 40;
@a = - 1 .. $b <=> 2;
print(@a,"\n");

# tests for correct precedence implemented
#   perl has higher precedence of .. over <=>
#   ans: -101 (in python: [-1,0,1] (equivalent))

#   (would use join but my code can't handle typecasting)
#   (more of a set 4 feature... haven't finished set 4)
