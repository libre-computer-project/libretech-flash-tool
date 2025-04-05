#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2022 Da Xue <da@libre.computer>

set -e

cd $(dirname $(readlink -f "${BASH_SOURCE[0]}"))

. lib/traps.sh
. lib/toolkit.sh
. lib/wget.sh
. lib/dmi.sh
. lib/board.sh
. lib/block-dev.sh

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
	if [ "${cmd%%-*}" = "b" -o "${cmd%%-*}" = "board" ]; then
		local action
		if [ ! -z "$1" ]; then
			local action=${1,,}
			shift
		fi
	elif [ "${cmd%%-*}" = "bl" -o "${cmd%%-*}" = "bootloader" ]; then 
		. lib/bootloader.sh
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
		. lib/distro.sh
		. lib/left.sh
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
	elif [ "${cmd%%-*}" = "left" ]; then
		. lib/distro.sh
		. lib/left.sh
		local dev="null"
		if [ ! -z "$1" ]; then
			local dev=$1
			shift
		fi
		local image=""
		if [ ! -z "$1" ]; then
			local image="$1"
			shift
		fi
	fi
	local param
	if [ ! -z "$1" ]; then
		local param=("$@")
	fi
	case ${cmd,,} in
		help)
			echo "COMMAND device-list board-help bootloader-help distro-help left-help" >&2
			return 1
			;;
		dev-list|device-list)
			BLOCK_DEV_get
			;;
		dev-list-all|device-list-all)
			BLOCK_DEV_get 1
			;;
		b-help|board-help)
			echo "COMMAND BOARD [DEVICE] [PARAMETERS]" >&2
			echo "b-list|board-list" >&2
			echo "b-emmc|board-emmc status" >&2
			echo "b-emmc|board-emmc bind|unbind|rebind" >&2
			echo "b-emmc|board-emmc show" >&2
			echo "b-emmc|board-emmc test read|write" >&2
			echo "b-bootrom|board-bootrom usb-drive BOARD [DEVICE] [INDEX]" >&2
			;;
		b-list|board-list)
			BOARD_list
			;;
		b-emmc|board-emmc)
			case ${action,,} in
				"status")
					BOARD_EMMC_isBound
					;;
				"bind"|"unbind"|"rebind"|"test")
					BOARD_EMMC_${action} "${param[@]}"
					;;
			esac
			;;
		b-bootrom|board-bootrom)
			. lib/bootloader.sh
			case "${action,,}" in
				"usb-drive")
					BOARD_BOOTROM_USB_drive "${param[@]}"
					;;
#				"usb-dfu")
#					BOARD_BOOTROM_USB_dfu "${param[@]}"
#					;;
				*)
					echo "BOARD BootROM: ${action,,} not supported or implemented."
					;;
			esac
			;;
		bl-help|bootloader-help)
			echo "COMMAND BOARD [DEVICE] [PARAMETERS]" >&2
			echo "bl-offset|bootloader-offset BOARD" >&2
			echo "bl-url|bootloader-url BOARD" >&2
			echo "bl-flash|bootloader-flash BOARD DEVICE force|verify" >&2
			echo "bl-wipe|bootloader-wipe DEVICE force|verify" >&2
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
			BOOTLOADER_flash "$board" "$dev" "${param[@]}"
			;;
		bl-wipe|bootloader-wipe)
			if [ -z "$board" ]; then
				echo "$0 ${cmd^^} BOARD [DEVICE]" >&2
				return 1
			fi
			BOOTLOADER_wipe "$board" "$dev" "${param[@]}"
			;;
		dist-help|distro-help)
			echo "COMMAND [DISTRO] [RELEASE] [VARIANT] [BOARD] [DEVICE] [PARAMETERS]" >&2
			echo "dist-list|distro-list [DISTRO] [RELEASE] [VARIANT] [BOARD]" >&2
			echo "dist-flash|distro-flash|distro-flash-left [DISTRO] [RELEASE] [VARIANT] [BOARD] [DEVICE] [PARAMETERS]" >&2
			return 1
			;;
		dist-list|distro-list)
			DISTRO_list "$distro" "$release" "$variant" "$board"
			;;
		dist-flash|distro-flash)
			DISTRO_flash "$distro" "$release" "$variant" "$board" "$dev" "${param[@]}"
			;;
		dist-flash-left|distro-flash-left)
			DISTRO_LEFT_flash "$distro" "$release" "$variant" "$board" "$dev" "${param[@]}"
			;;
		left-help)
			echo "COMMAND [DEVICE] [IMAGE] [PARAMETERS]" >&2
			echo "left-flash [DEVICE] [IMAGE] [PARAMETERS]" >&2
			return 1
			;;
		left-flash)
			LEFT_flash "$dev" "$image" "${param[@]}"
			;;
		*)
			echo "$FUNCNAME: COMMAND $cmd is not valid." >&2
			exit 1
			;;
	esac
}

main "$@"
