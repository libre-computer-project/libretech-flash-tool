#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2022 Da Xue <da@libre.computer>

BLOCK_DEV_get(){
	local blk_show_all=${1:-0}
	local blk_devs=$(lsblk -dn | cut -f 1 -d " ")
	local blk_dev
	local blk_part
	for blk_dev in $blk_devs; do
		local blk_show=1
		for blk_part in $(ls /dev/$blk_dev*); do
			case "$(findmnt -no TARGET $blk_part)" in
				"")
					:
					;;
				/media/*)
					:
					;;
				*)
					local blk_show=0
					break
					;;
			esac
		done
		if [ "$blk_show" -eq 1 -o "$blk_show_all" -eq 1 ]; then
			echo $blk_dev
		fi
	done
}

BLOCK_DEV_isValid(){
	local dev=$1
	local blk_show_all=${2:-0}
	if [ "$dev" = "null" ]; then
		return 0
	fi
	for _dev in $(BLOCK_DEV_get $blk_show_all); do
		if [ "$dev" = "$_dev" ]; then
			return 0
		fi
	done
	return 1
}

BLOCK_DEV_isMounted(){
	local dev=$1
	if [ "$dev" = "null" ]; then
		return 1
	fi
	for blk_part in $(ls /dev/$dev*); do
		local blk_mnt=$(findmnt -no TARGET $blk_part)
		if [ ! -z "$blk_mnt" ]; then
			return 0
		fi
	done
	return 1
}

BLOCK_DEV_getInfo(){
	local dev=$1
	lsblk -dnyo TRAN,SIZE,VENDOR,MODEL,SERIAL /dev/$dev
}

BLOCK_DEV_getPartPrefix(){
	if [ "${1/\/dev\/mmcblk/}" != "$1" ]; then
		echo -n "p"
	elif [ "${1/\/dev\/nvme/}" != "$1" ]; then
		echo -n "p"
	elif [ "${1/\/dev\/loop/}" != "$1" ]; then
		echo -n "p"
	fi
}

BLOCK_DEV_mkfs(){
	local type="$1"
	local target="$2"
}
