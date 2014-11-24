#!/bin/sh

PATH="$PATH:/bin"

echo -ne "Content-type: text/plain; charset=\"UTF-8\"\r\n\r\n"
a=`cat`
while read line;
do echo "$line" >> /tmp/readline
done

echo "$a" > /tmp/readline
env > /tmp/env
cat <<EOF
{
	$a
	`env`
}
EOF
