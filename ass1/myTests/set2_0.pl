#!/usr/bin/perl
# comma argument leaves a space between result and \n
# "="
print("=========SET2_0=========\n");
print("***(part 1 of tests)\n");
$answer = 4 + 3;
print($answer,"\n");
print ("$answer\n");
# "+", "-", "/", "%", "**", "*"
print(4 + 7,"\n");
print(4 - 7,"\n");
print(19 / 7,"\n");
print(19 % 7,"\n");
print(4 ** 7,"\n");
print(4 * 7,"\n");
print("***(part 1.5 of tests)\n");
print(4+7,"\n");
print(4-7,"\n");
print(19/7,"\n");
print(19%7,"\n");
print(4**7,"\n");
print(4*7,"\n");
# "||, ""&&", "!", "and", "or", "not"
print("***(part 2 of tests)\n");
print(0 ||0,"\n");
print(1|| 0,"\n");
print(2 &&0,"\n");
print(3 && 3,"\n");
print(4 &&!1,"\n");    # todo: handle brackets??
print(5 && !0,"\n");
print(1 and 0,"\n");
print(1 or 0,"\n");
print(1 and not 1,"\n");
print(1 and not 0,"\n");
# "<", "<=", ">", ">=", "<=>", "!=", "=="
print("***(part 3 of tests)\n");
print (0<5,"\n");                   # true
print (6    <        5,"\n");       # false
print (2<=1,"\n");                  # f
print (1    <= 1,"\n");             # t
print (6>5,"\n");                   # t
print (0    >     5,"\n");          # f
print (1>=2,"\n");                  # f
print (1   >=            1,"\n");    # t
print(2<=>4,"\n");                  # -1
print(5 <=> 4,"\n");                # 1
print(6 !=2,"\n");                  # t
print(2 !=2,"\n");                  # f
print(3== 3,"\n");                  # t
# "|", "^", "&", "<<", ">>", "~"
print("***(part 4 of tests)\n");
print(0x2|0x1,"\n");            # 0x11 = 3
print(0b0^00,"\n");             # every bit is 0
print(0b0^~00,"\n");            # every bit is 1
print(0xABCDEF&0x1,"\n");       # 1
print(0x1<< 3,"\n");           # 8
print(16 >>2,"\n");            # 4
