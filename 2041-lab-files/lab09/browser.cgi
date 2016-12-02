#!/bin/sh
# http://cgi.cse.unsw.edu.au/~z5075018/lab09/browser.cgi
echo Content-type: text/html
echo

# provided code is buggy?? (why are we grepping??)
# 2>&1 (channel 2 (stderr) is sent to channel 1 (stdout))
# host_address=`host $REMOTE_ADDR 2>&1|grep Name|sed 's/.*: *//'`

host_address=`host $REMOTE_ADDR 2>&1 | sed 's/.*pointer \(.*\)\./\1/'`

cat <<eof
<!DOCTYPE html>
<html lang="en">
<head>
<title>IBrowser IP, Host and User Agent</title>
</head>
<body>
Your browser is running at IP address: <b>$REMOTE_ADDR</b>
<p>
Your browser is running on hostname: <b>$host_address</b>
<p>
Your browser identifies as: <b>$HTTP_USER_AGENT</b>
</body>
</html>
eof

# `echo $HTTP_VIA | cut -d' ' -f2 | cut -d':' -f1`
