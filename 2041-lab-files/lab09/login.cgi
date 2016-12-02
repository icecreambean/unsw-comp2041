#!/usr/bin/perl -w
# http://cgi.cse.unsw.edu.au/~z5075018/lab09/login.cgi
use CGI qw/:all/;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser/;

print header, start_html('Login');
warningsToBrowser(1);

$username = param('username') || '';
$password = param('password') || '';
chomp $username;
chomp $password;

if ($username ne '' && $password ne '') {
    if (open(F, "<accounts/$username/password")) {
		$line = <F>;
		chomp $line;
		if ($line eq $password) {
			print "$username authenticated.\n";
		} else {
			print "Incorrect password!\n";
		}
	} else {
		print "Unknown username!\n";
	}
} else {
    print start_form, "\n";
    # do this using hidden fields
    if ($username eq "") {
        print "Username:\n", textfield('username');
    } else {
        # generate <input type="hidden"...> html tag
        print hidden(-name => 'username', -default => $username);
    }
    if ($password eq "") {
        print "Password:\n", textfield('password');
    } else {
        print hidden(-name => 'password', -default => $password);
    }
    print submit(value => Login), "\n";
    print end_form, "\n";
}
print end_html;
exit(0);
