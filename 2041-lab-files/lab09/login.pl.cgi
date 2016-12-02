#!/usr/bin/perl -w
# http://cgi.cse.unsw.edu.au/~z5075018/lab09/login.pl.cgi
use CGI qw/:all/;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser/;
# check if using command line or not
if (!exists $ENV{GATEWAY_INTERFACE}) {
    print "username: ";
    $username = <STDIN>;
    print "password: ";
    $password = <STDIN>;
    chomp $username;
    chomp $password;
    verify(0);
    exit 0;
}

print header, start_html('Login');
warningsToBrowser(1);
#print `env`; # debug code

$username = param('username') || '';
$password = param('password') || '';
chomp $username;
chomp $password;

#####################
sub verify {
    ($mode) = @_; # 0 for command line, 1 for cgi
    if (open(F, "<accounts/$username/password")) {
		$line = <F>;
		chomp $line;
		if ($line eq $password) {
            print "You are authenticated.\n" if $mode == 0;
			print "$username authenticated.\n" if $mode == 1;
		} else {
			print "Incorrect password!\n";
		}
	} else {
		print "Unknown username!\n";
	}
}
######## CGI ########

if ($username ne '' && $password ne '') {
    verify(1);
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
