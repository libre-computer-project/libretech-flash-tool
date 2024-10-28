#!/usr/bin/env bash
if [ -z "$1" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
	echo "$0 dt|config board[/master|linux-rolling-lts|linux-rolling-stable]" >&2
	exit 1
fi

case "$1" in
	"dt")
		target=dts
		;;
	"config")
		target=config
		;;
	*)
		echo "?" >&2
		exit 1
		;;
esac

getURL(){
	board="${1%%/*}"
	if [ "$board" != "$1" ]; then
		release="${1#*/}"
		echo "http://boot.libre.computer/vanilla/$board/$release/$board-$release.$target"
	else
		echo "http://boot.libre.computer/ci/$1.$target"
	fi
}

url1=$(getURL "$2")
url2=$(getURL "$3")
echo "$url1"
echo "$url2"
diff -y --color=always -W $(tput cols) <(curl "$url1") <(curl "$url2") | grep -v "phandle = "
