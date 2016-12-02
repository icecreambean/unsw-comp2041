#!/usr/bin/perl -w
# put your demo script here

# input: enter some personal details which are then printed out

print "Enter your first name: ";
$first_name = <STDIN>;
print "Enter your last name : ";
$last_name = <stdin>;
print "Enter your student id: ";
$id = <STDIN>;
print "Enter your school fees: ";
$fees = <STDIN>;

chomp $first_name;
    chomp $last_name;
chomp $id; chomp $fees;

print ("Welcome to UNSW, $first_name $  last_name.\n");
print ("\tYour id is: $ { id }.");
print("\n");
print ("\tYou are owing us a total of \$$fees.\n");
