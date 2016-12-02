COUNTA=0
COUNTB=0
SPACEDWORD=""
for WORD in `egrep '^A*B*$' file4`;
do
    let SPACEDWORD = `sed 's/\(.\)/\1 /g' < $WORD`
    for C in $SPACEDWORD;
    do
        echo $C
    done
done
