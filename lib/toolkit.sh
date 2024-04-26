#!/bin/bash
# SPDX-License-Identifier: CC-BY-NC-4.0
# Copyright (C) 2022 Da Xue <da@libre.computer>

TOOLKIT_isIn(){
	local search="$1"
	shift
	for param in "$@"; do
		if [ "$search" = "$param" ]; then
			return 0
		fi
	done
	return 1
}
TOOLKIT_isInCaseInsensitive(){
	local search="$1"
	shift
	for param in "$@"; do
		if [ "${search,,}" = "${param,,}" ]; then
			return 0
		fi
	done
	return 1
}
TOOLKIT_promptYesNo(){
	while true; do
		read -s -n 1 -p "(y/n)" confirm
		echo
		case "${confirm,,}" in
			y|yes)
				break
				;;
			n|no)
				return 1
				;;
		esac
	done
}
TOOLKIT_urlDecode(){
	: "${*//+/ }"
	echo -en "${_//%/\\x}"
}
