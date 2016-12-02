#!/usr/bin/perl -w

my $flag = 0;
my $zid = 'z5119437';
my @message = ();
while (my $line = <STDIN>) {
    if ($line =~ /^FOUND/) {
        if ($flag == 1) {
            print(join("",@message),"\n");
            @message = ();
        }
        $flag = 1;
    }
    push (@message, $line) if ($flag == 1);
    if ($line =~ /$zid/) {
        $flag = 0;
        @message = ();
        next;
    }
}
