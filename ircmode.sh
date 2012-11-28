#!/bin/bash

channel=\#timeofeve
nick=enki-v
server=irc.freenode.com
opts=""

if [[ $# -gt 0 ]];  then
	if [[ $1 == "-h" ]]; then
		echo -e "Usage: $0 [[-h] | [channel [nick [server [options ...]]]]]\nOptions after server are passed to fe.lua"
		exit
	else
		channel=$1
		if [[ $# -gt 1 ]] ; then
			nick=$2
			if [[ $# -gt 2 ]] ; then
				server=$3
				if [[ $# -gt 3 ]] ; then
					shift
					shift
					shift
					opts=$@
				fi
			fi
		fi
	fi
fi

echo "============================================================="
which figlet > /dev/null && echo "LameMCMC" | figlet && echo "               ircmode" || echo "LameMCMC ircmode"
echo
echo "============================================================="
echo "PID: $$"
echo "tempfile: $(pwd)/.$$"
echo "$nick@$server/$channel"
echo "============================================================="
echo

rm -f .$$
touch .$$
echo >> .$$
echo >> .$$
echo >> .$$
echo >> .$$
echo >> .$$
pid=$$
tail -s 0.5 -f .$$ | tee /dev/stderr | (./fe.lua -nt -i && rm -f .$pid && kill $pid) | irc -c $channel $nick $server  >> .$$
rm -f .$$

