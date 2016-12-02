#!/usr/bin/perl -w
# validate a credit card number by calculating its
# checksum using Luhn's formula (https://en.wikipedia.org/wiki/Luhn_algorithm)

use strict;
use warnings;

sub luhn_checksum {
	my ($number) = @_;
	my $checksum = 0;
	my @digits =  reverse(split("", $number));
	my $index = 0;
	foreach my $digit (@digits) {
		my $multiplier = 1 + $index % 2;
		my $d = $digit * $multiplier;
		$d -= 9 if $d > 9;
		$checksum += $d;
		$index++;
	}
	return $checksum;
}

sub validate {
	my ($credit_card) = @_;
	my $number = $credit_card;
	$number =~ s/\D//g;
	if (length($number) != 16) {
		return $credit_card . " is invalid - does not contain exactly 16 digits";
	}
	if (luhn_checksum($number) % 10 == 0) {
		return $credit_card . " is valid";
	}
	return $credit_card . " is invalid";
}

foreach my $arg (@ARGV) {
	print(validate($arg) . "\n");
}
