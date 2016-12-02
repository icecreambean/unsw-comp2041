#!/usr/bin/perl -w
# validate a credit card number by calculating its
# checksum using Luhn's formula (https://en.wikipedia.org/wiki/Luhn_algorithm)

use strict;
use warnings;

use CGI qw/:all/;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser/;
use HTML::Entities;		# for sanitising

############################ from .pl file ##############################

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

# modified such that you have to add the leading credit_card val yourself
sub validate {
	my ($credit_card) = @_;
	my $number = $credit_card;
	$number =~ s/\D//g;
	if (length($number) != 16) {
		return " is invalid - does not contain exactly 16 digits";
	}
	if (luhn_checksum($number) % 10 == 0) {
		return " is valid";
	}
	return " is invalid";
}

########################### Shell ##################################
#foreach my $arg (@ARGV) {
#	print(validate($arg) . "\n");
#}

############################# CGI ##################################

my $is_close = param("is_close"); # only used as a bool
my $credit_card = param("credit_card");
my $is_validate = param("is_validate"); # only used as a bool
# 		sanitise your inputs if they are used in printing / args
# 		embedded in some other language
my $credit_card_sanitised = HTML::Entities::encode($credit_card);

print header, start_html("Credit Card Validation"), "\n";
warningsToBrowser(1);
print h2("Credit Card Validation"), "\n";

# check if "close"
if (defined $is_close) {
	#print("'" . $is_close . "'","\n");		# value will be 'Close'
	print "Thank you for using the Credit Card Validator.","\n";
	print end_html;
	exit 0;
}
# otherwise: "verify" / "reset" page
print "This page checks whether a potential credit card number satisfies the Luhn Formula.", "\n";
print p(), "\n";	# copying the required spec

my $text_command = "Enter credit card number:";
if (defined $is_validate) {
	# ensure result sanitised as result will be printed
	my $result = $credit_card_sanitised . validate($credit_card);
	if ($result =~ /invalid/) {
		# print result in red and keep the result in textfield
		print b(font({-color => 'red'}, $result)), "\n";
		$text_command = "Try again:";
	} else {
		print $result, "\n";
		$credit_card = undef;
		$text_command = "Another card number:";
	}
}

#print start_form(-method => 'GET'), "\n";
print start_form, "\n";	# default: POST
print "$text_command\n",
	  textfield(-name => 'credit_card', -value => $credit_card, -override => 1),
	  "\n";
print submit(-name => 'is_validate', -value => "Validate"), "\n";
print reset(-value => "Reset"), "\n";
print submit(-name => 'is_close', -value => "Close"), "\n";
print end_form, "\n";

print end_html;

# note: cgi functions match identically html tags
# https://www.cs.tut.fi/~jKorpela/perl/cgi.html
# http://www.perl.com/pub/2002/02/20/css.html
