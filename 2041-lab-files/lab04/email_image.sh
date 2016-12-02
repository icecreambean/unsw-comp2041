#!/bin/sh

# view each image ("$@" to preserve filename spaces)
for file in "$@"
do
    display "$file"
    printf "Address to e-mail this image to? "
    read email
    printf "Message to accompany image? "
    read message
    # must have set up an email server to send messages
    # protection on "@cse.unsw.edu.au" might be weaker
    # hence this program can work (even w/o security
    # features)
    echo "$message" | mutt -s "COMP2041 lab04" -a "$file" -- "$email"
    printf "$file sent to $email\n"
done

# echo -n is unreliable in the Bourne shell
