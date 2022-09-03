#!/bin/bash
# SPDX-License-Identifier: CC-BY-NC-4.0
# Copyright (C) 2022 Da Xue <da@libre.computer>

BLOCK_DEV_get(){
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
		if [ "$blk_show" -eq 1 ]; then
			echo $blk_dev
		fi
	done
}

BLOCK_DEV_isValid(){
	local dev=$1
	if [ "$dev" = "null" ]; then
		return 0
	fi
	for _dev in $(BLOCK_DEV_get); do
		if [ "$dev" = "$_dev" ]; then
			return 0
		fi
	done
	return 1
}