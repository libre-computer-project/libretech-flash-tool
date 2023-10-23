#!/bin/bash
# SPDX-License-Identifier: CC-BY-NC-4.0
# Copyright (C) 2021 Da Xue <da@libre.computer>

declare -A BOOTLOADER_OFFSET=(
	[all-h3-cc-h3]=16
	[all-h3-cc-h5]=16
	[aml-a311d-cc]=1
	[aml-s805x-ac]=1
	[aml-s905x-cc]=1
	[aml-s905x-cc-v2]=1
	[aml-s905d-pc]=1
	[aml-s905d3-cc]=1
	[roc-rk3328-cc]=64
	[roc-rk3399-pc]=64
	)

BOOTLOADER_URL="https://boot.libre.computer/ci/"
BOOTLOADER_BLK_SIZE=512
BOOTLOADER_isValid(){
	local board=$1
	local _board
	for _board in ${!BOOTLOADER_OFFSET[@]}; do
		if [ "$board" = "$_board" ]; then
			return 0
		fi
	done
	return 1
}

BOOTLOADER_getOffset(){
	local board=$1
	if [ "${board##*-}" = "spiflash" ]; then
		echo -n 0
		return
	elif [ "${board##*-}" = "nfs" ]; then
		echo -n 0
		return
	elif [ "${board##*-}" = "test" ]; then
		echo -n 0
		return
	fi
	while [ -z "${BOOTLOADER_OFFSET[$board]}" ]; do
		local board_new="${board%-*}"
		if [ -z "$board_new" ] || [ "$board_new" = "$board" ]; then
			echo "$FUNCNAME: BOARD $1 is not supported" >&2
			return 1
		fi
		local board="$board_new"
	done
	echo -n ${BOOTLOADER_OFFSET[$board]}
}

BOOTLOADER_getURL(){
	echo -n "${BOOTLOADER_URL}${1}"
}

BOOTLOADER_getHeaders(){
	WGET_getHeaders "$BOOTLOADER_URL/$1"
}

BOOTLOADER_get(){
	local board=$1
	local bl=$2
	echo "$FUNCNAME: downloading $board bootloader to $bl."
	echo
	wget -O $bl "$BOOTLOADER_URL/$board" 2>&1
	echo "$FUNCNAME: downloaded $board bootloader to $bl."
}

BOOTLOADER_flash(){
	local board=$1
	local bl=$2
	local dev=$3
	shift 3
	local force=0
	if TOOLKIT_isInCaseInsensitive "force" "$@"; then
		local force=1
	fi
	local verify=0
	if TOOLKIT_isInCaseInsensitive "verify" "$@"; then
		local verify=1
	fi

	local dev_path=/dev/$dev

	if ! BLOCK_DEV_isValid $dev $force; then
		echo "$FUNCNAME: DEVICE $dev is not a valid target." >&2
		return 1
	fi

	if BLOCK_DEV_isMounted $dev; then
		echo "$FUNCNAME: !!!WARNING!!! DEVICE $dev is mounted." >&2
	fi

	if [ ! -w "$dev_path" ]; then
		echo "$FUNCNAME: DEVICE $dev is not writable by current user $USER." >&2
		return 1
	fi

	if ! BOOTLOADER_getHeaders $board > $bl; then
		if grep -io "HTTP/1.1\s404\sNot\sFound" $bl > /dev/null; then
			echo "$FUNCNAME: BOARD $board bootloader could not be found." >&2
		else
			echo "$FUNCNAME: BOARD $board bootloader server could not be reached." >&2
		fi
		return 1
	fi
	local bl_size=$(grep -o "Content-Length:\s\+[0-9]*" $bl | tr -s " " | cut -f 2 -d " ")
	if [ $bl_size -lt $((100*1024)) ]; then
		echo "$FUNCNAME: BOARD $board bootloader size is unexpectedly small." >&2
		return 1
	fi
	if ! BOOTLOADER_get $board $bl; then
		echo "$FUNCNAME: BOARD $board bootloader could not be downloaded." >&2
		return 1
	fi

	if [ $(stat -c %s $bl) -ne $bl_size ]; then
		echo "$FUNCNAME: BOARD $board bootloader does not match expected size." >&2
		return 1
	fi

	if BLOCK_DEV_isMounted $dev; then
		echo "$FUNCNAME: !!!WARNING!!! DEVICE $dev is mounted." >&2
	fi

	local bl_dd_seek=""
	local bl_offset=$(BOOTLOADER_getOffset $board)
	if [ $bl_offset -eq 0 ]; then
		local bl_block_size=1M
	else
		local bl_block_size=$BOOTLOADER_BLK_SIZE
		local bl_dd_seek="seek=$bl_offset"
	fi
	local bl_flash_cmd="dd if=$bl of=$dev_path bs=$bl_block_size $bl_dd_seek status=progress"

	if [ "$force" -eq 0 ]; then
		echo "$FUNCNAME: $bl_flash_cmd" >&2
		echo "$FUNCNAME: run the above command to flash the target device?" >&2
		while true; do
			read -s -n 1 -p "(y/n)" confirm
			echo
			case "${confirm,,}" in
				y|yes)
					echo "$bl_flash_cmd"
					break
					;;
				n|no)
					echo "$FUNCNAME: operation cancelled." >&2
					return 1
					;;
			esac
		done
	fi

	if $bl_flash_cmd; then
		sync $dev_path
		echo "$FUNCNAME: bootloader written to $dev successfully." >&2
		if [ "$verify" -eq 1 ]; then
			local bl_sector_count=$(((bl_size+$BOOTLOADER_BLK_SIZE-1)/$BOOTLOADER_BLK_SIZE))
			if cmp <(dd if=$bl bs=$BOOTLOADER_BLK_SIZE count=$bl_sector_count 2> /dev/null) \
					<(dd if=$dev_path bs=$BOOTLOADER_BLK_SIZE count=$bl_sector_count skip=$bl_offset 2> /dev/null) > /dev/null; then
				echo "$FUNCNAME: bootloader written to $dev verified." >&2
			else
				echo "$FUNCNAME: bootloader written to $dev failed verification!" >&2
			fi
		fi
	else
		echo "$FUNCNAME: bootloader write to $dev failed!" >&2
		return 1
	fi
}

BOOTLOADER_wipe(){
	local board=$1
	local dev=$2
	shift 2
	local force=0
	if TOOLKIT_isInCaseInsensitive "force" "$@"; then
		local force=1
	fi

	local dev_path=/dev/$dev

	if ! BLOCK_DEV_isValid $dev $force; then
		echo "$FUNCNAME: DEVICE $dev is not a valid target." >&2
		return 1
	fi

	if BLOCK_DEV_isMounted $dev; then
		echo "$FUNCNAME: !!!WARNING!!! DEVICE $dev is mounted." >&2
	fi

	if [ ! -w "$dev_path" ]; then
		echo "$FUNCNAME: DEVICE $dev is not writable by current user $USER." >&2
		return 1
	fi

	if BLOCK_DEV_isMounted $dev; then
		echo "$FUNCNAME: !!!WARNING!!! DEVICE $dev is mounted." >&2
	fi

	local bl_dd_seek=""
	local bl_offset=$(BOOTLOADER_getOffset $board)
	local bl_block_size=$BOOTLOADER_BLK_SIZE
	local bl_dd_seek="seek=$bl_offset"
	local bl_count="count=$((2048-bl_offset))"
	local bl_flash_cmd="dd if=/dev/zero of=$dev_path bs=$bl_block_size $bl_dd_seek $bl_count status=progress"

	if [ "$force" -eq 0 ]; then
		echo "$FUNCNAME: $bl_flash_cmd" >&2
		echo "$FUNCNAME: run the above command to flash the target device?" >&2
		while true; do
			read -s -n 1 -p "(y/n)" confirm
			echo
			case "${confirm,,}" in
				y|yes)
					echo "$bl_flash_cmd"
					break
					;;
				n|no)
					echo "$FUNCNAME: operation cancelled." >&2
					return 1
					;;
			esac
		done
	fi

	if $bl_flash_cmd; then
		sync $dev_path
		echo "$FUNCNAME: bootloader wiped from $dev successfully." >&2
	else
		echo "$FUNCNAME: bootloader wipe from $dev failed!" >&2
		return 1
	fi
}
