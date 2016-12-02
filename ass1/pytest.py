#!/usr/local/bin/python3.5 -u
import sys
sys.argv.pop(0)
# put your demo script here
print ("Enter your first name: ", end="", sep="", flush=True);
first_name  = sys.stdin.readline();
print ("Enter your last name : ", end="", sep="", flush=True);
last_name  = sys.stdin.readline();
print ("Enter your student id: ", end="", sep="", flush=True);
id  = sys.stdin.readline();
print ("Enter your school fees: ", end="", sep="", flush=True);
fees  = sys.stdin.readline();

first_name = first_name.rstrip('\n');
last_name = last_name.rstrip('\n');
id = id.rstrip('\n'); fees = fees.rstrip('\n');

print ("Welcome to UNSW, {} {}.\n".format(first_name, last_name), end="", sep="", flush=True);
print ("\tYour id is: {}.".format(id), end="", sep="", flush=True);
print("\n", end="", sep="", flush=True);
print ("\tYou are owing us a total of ${}.\n".format(fees), end="", sep="", flush=True);
