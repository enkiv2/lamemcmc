#!/bin/bash

###################################################################
# ircmode.sh
# Copyright (c) 2012 John Ohno
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
###################################################################

channel=\#timeofeve
nick=enki-v
server=irc.freenode.com
opts=""

if [[ $# -gt 0 ]];  then
	if [[ $1 == "-h" ]]; then
		echo "Usage: $0 [-h] | [channel [nick [server [options ...]]]]"
		echo "Options after server are passed to fe.lua"
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
# If we have figlet, do a nice fancy logo
which figlet > /dev/null && \
	echo "LameMCMC" | figlet && \
	echo "               ircmode" || \
echo "LameMCMC ircmode"
echo
echo "============================================================="
echo "PID: $$"
echo "tempfile: $(pwd)/.$$"
echo "$nick@$server/$channel"
echo "============================================================="
echo

# Clean up old copy. (Will people really leave stale logs around long enough
# to have a PID collision??)
rm -f .$$
touch .$$
# Buffer five lines in there.
echo >> .$$
echo >> .$$
echo >> .$$
echo >> .$$
echo >> .$$
# Subshell might have a different pid. (Haven't checked)
pid=$$
tail -s 0.5 -f .$$ | tee /dev/stderr | \
	 (./fe.lua -nt -i && rm -f .$pid && kill $pid) | \
	 irc -c $channel $nick $server  >> .$$
rm -f .$$

