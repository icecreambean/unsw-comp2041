#!/usr/bin/perl
print("=========SET3_4=========\n");
print( 2 + 1 .. 3 + 4 , "\n" );
$a = 1;
$b = 40;
print($a + 2 .. $b / 8, "\n");

print( 1 <=> $a .. 6 <=> 2 ,"\n" );

print( 1 <=> 2 .. 6 ,"\n" );
print( 0 .. 6 <=> 2,"\n" );

print( -1 .. 6 <=> 2,"\n" );   # fix this one

# 3 to 7,
# 3 to 5,
# 0 to 1
# -1 to 6
# 0 to 1
# -1 to 1
