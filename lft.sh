#!/bin/bash
# SPDX-License-Identifier: CC-BY-NC-4.0
# Copyright (C) 2022 Da Xue <da@libre.computer>

set -e

cd $(dirname $(readlink -f "${BASH_SOURCE[0]}"))

. lib/traps.sh
. lib/toolkit.sh
. lib/wget.sh
. lib/block-dev.sh
. lib/board.sh
. lib/bootloader.sh
. lib/distro.sh

#1 command {flash}
#2 board
#3 block device
#4+ parameter

main(){
	local cmd="help"
	if [ ! -z "$1" ]; then
		local cmd=$1
		shift
	fi
	if [ "${cmd%%-*}" = "bl" -o "${cmd%%-*}" = "bootloader" ]; then 
		local board
		if [ ! -z "$1" ]; then
			local board=${1,,}
			shift
		fi
		local dev="null"
		if [ ! -z "$1" ]; then
			local dev=$1
			shift
		fi
	elif [ "${cmd%%-*}" = "dist" -o "${cmd%%-*}" = "distro" ]; then
		local distro
		if [ ! -z "$1" ]; then
			local distro=${1,,}
			shift
		fi
		local release
		if [ ! -z "$1" ]; then
			local release=${1,,}
			shift
		fi
		local variant
		if [ ! -z "$1" ]; then
			local variant=${1,,}
			shift
		fi
		local board
		if [ ! -z "$1" ]; then
			local board=${1,,}
			shift
		fi
		local dev="null"
		if [ ! -z "$1" ]; then
			local dev=$1
			shift
		fi
	fi
	local param
	if [ ! -z "$1" ]; then
		local param=("$@")
	fi
	case ${cmd,,} in
		help)
			echo "COMMAND device-list board-list bootloader-help distro-help" >&2
			return 1
			;;
		dev-list|device-list)
			BLOCK_DEV_get
			;;
		b-list|board-list)
			BOARD_list
			;;
		bl-help|bootloader-help)
			echo "COMMAND BOARD [DEVICE] [PARAMETERS]" >&2
			echo "bl-offset|bootloader-offset BOARD" >&2
			echo "bl-url|bootloader-url BOARD" >&2
			echo "bl-flash|bootloader-flash BOARD DEVICE force|verify" >&2
			return 1
			;;
		bl-offset|bootloader-offset)
			if [ -z "$board" ]; then
				echo "$0 ${cmd^^} BOARD" >&2
				return 1
			fi
			if ! BOOTLOADER_isValid $board; then
				echo "$FUNCNAME: BOARD $board is not valid." >&2
				return 1
			fi
			echo $(BOOTLOADER_getOffset $board)
			;;
		bl-url|bootloader-url)
			if [ -z "$board" ]; then
				echo "$0 ${cmd^^} BOARD" >&2
				return 1
			fi
			echo $(BOOTLOADER_getURL $board)
			;;
		bl-flash|bootloader-flash)
			if [ -z "$board" ]; then
				echo "$0 ${cmd^^} BOARD [DEVICE]" >&2
				return 1
			fi
			traps_start
			local bl=$(mktemp)
			traps_push rm $bl
			
			BOOTLOADER_flash "$board" "$bl" "$dev" "${param[@]}"
			
			traps_pop
			traps_stop
			;;
		dist-help|distro-help)
			echo "COMMAND [DISTRO] [RELEASE] [VARIANT] [BOARD] [DEVICE] [PARAMETERS]" >&2
			echo "dist-list|distro-list [DISTRO] [RELEASE] [VARIANT] [BOARD]" >&2
			echo "dist-flash|distro-flash [DISTRO] [RELEASE] [VARIANT] [BOARD] [DEVICE] [PARAMETERS]" >&2
			return 1
			;;
		dist-list|distro-list)
			DISTRO_list $distro $release $variant $board
			;;
		dist-flash|distro-flash)
			DISTRO_flash $distro $release $variant $board $dev ${param[@]}
			;;
		*)
			echo "$FUNCNAME: COMMAND $cmd is not valid." >&2
			exit 1
			;;
	esac
}

main "$@"