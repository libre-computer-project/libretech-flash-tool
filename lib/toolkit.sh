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