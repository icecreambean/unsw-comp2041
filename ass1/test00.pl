#!/usr/bin/perl -w
# put your demo script here
print(0.12,"\n");
print(00.12,"\n");
# first one is a decimal number
# second one is an octal number (0) that is then string concatenated to a
# decimal number (12)

print(1_2,"\n");
print(0__.4,"\n");
print(1__.3,"\n");
# third one prints: 12 (underscore not supported in python)
# fourth one prints: 04 (string concat caused by underscore separator)
# fifth one reads as a decimal number again

print(2e_+2,"\n");
print(2_e+2,"\n");
print(2e+_2,"\n");
# these all print 200
print(2e+_+_2);
# this prints 2
print(2e_+_+2,"\n");
# this prints 4
