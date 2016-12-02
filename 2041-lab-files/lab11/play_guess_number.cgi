#!/usr/bin/perl -w

use CGI qw/:all/;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);

print <<eof;
Content-Type: text/html

<!DOCTYPE html>
<html lang="en">
<head>
    <title>A Guessing Game Player</title>
</head>
<body>
eof

warningsToBrowser(1);

$guess = param('guess') || 50;
$min = param('min') || 1;
$max = param('max') || 100;
$guess =~ s/\D//g;
$min =~ s/\D//g;
$max =~ s/\D//g;

if (defined param('higher')) {
	$min = $guess + 1;
	$diff = ($max - $guess)/2;
	$diff += 0.5 if ($diff - int($diff) != 0);
	$guess += int($diff);
} 
elsif (defined param('lower')) {
	$max = $guess - 1;
	$diff = ($guess - $min + 1)/2;
	$diff += 0.5 if ($diff - int($diff) != 0);
	$guess -= int($diff);
}

if (defined param('correct')) {
	print <<eof;
    <form method="POST" action="">
		I win!!!!
        <input type="submit" value="Play Again">
    </form>
eof
	# will resubmit form without param 'guess'
} 
else {
	print <<eof;
    <form method="POST" action="">
		My guess is: $guess 
        <input type="submit" name="higher" value="Higher?">
		<input type="submit" name="correct" value="Correct?">
		<input type="submit" name="lower" value="Lower?">
        <input type="hidden" name="guess" value="$guess">
		<input type="hidden" name="min" value="$min">
		<input type="hidden" name="max" value="$max">
    </form>
eof
}

print <<eof;
</body>
</html>
eof
