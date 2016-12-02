#!/usr/bin/perl
print("=========SET3_0=========\n");
$eq = 1;$ne = 2;$lt = 3;$gt = 5; $cmp = " cmp "; # etc.

if ("a" eq "a") {
    print("$eq\n");
}
if ("a" ne "b") {
    print("$ne\n");
}
if ("a" lt "b") {
    print("$lt\n");
}
if ("a" le "a") {
    print("4\n");
}
if ("a" le "b") {
    print("4.5\n");
}
if ("z" gt "a") {
    print("$gt\n");
}
if ("z" ge "a") {
    print("6\n");
}
if ("a" ge "a") {
    print("7\n");
}

if ("a" cmp "a") {
    print("$cmp: 0\n");
}
if ("a" cmp "b") {
    print("$cmp: -1\n");
}
if ("z" cmp "a") {
    print("$cmp: 1\n");
}
