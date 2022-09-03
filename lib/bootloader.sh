#!/bin/bash
# SPDX-License-Identifier: CC-BY-NC-4.0
# Copyright (C) 2021 Da Xue <da@libre.computer>

declare -A BOOTLOADER_OFFSET=(
	[all-h3-cc-h3]=16
	[all-h3-cc-h5]=16
	[aml-s805x-ac]=1
	[aml-s905x-cc]=1
	[aml-s905x-cc-v2]=1
	[roc-rk3328-cc]=64
	[roc-rk3399-pc]=64
	)

BOOTLOADER_URL="https://boot.libre.computer/ci/"

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

BOOTLOADER_list(){
	local _board
	for _board in ${!BOOTLOADER_OFFSET[@]}; do
		echo $_board
	done
}

BOOTLOADER_getOffset(){
	echo -n ${BOOTLOADER_OFFSET[$1]}
}

BOOTLOADER_getURL(){
	echo -n "${BOOTLOADER_URL}${1}"
}

BOOTLOADER_getHeaders(){
	local board=$1
	wget -S --spider "https://boot.libre.computer/ci/$board" 2>&1
}

BOOTLOADER_get(){
	local board=$1
	local bl=$2
	echo "$FUNCNAME: downloading $board bootloader to $bl."
	echo
	wget -O $bl "https://boot.libre.computer/ci/$board" 2>&1
	echo "$FUNCNAME: downloaded $board bootloader to $bl."
}

BOOTLOADER_flash(){
	local board=$1
	local bl=$2
	local dev=$3
	local dev_path=/dev/$dev
	
	if ! BLOCK_DEV_isValid $dev; then
		echo "$FUNCNAME: DEVICE $dev is not a valid target." >&2
		return 1
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
	
	local bl_offset=$(BOOTLOADER_getOffset $board)
	local bl_flash_cmd="dd if=$bl of=$dev_path oflag=dsync bs=512 seek=$bl_offset"
	echo "$FUNCNAME: $bl_flash_cmd"
	echo "$FUNCNAME: run the above command to flash the target device?"
	while true; do
		read -s -n 1 -p "Confirm (y/n)" confirm
		case "${confirm,,}" in
			y|yes)
				break
				;;
			n|no)
				echo
				return 1
				;;
		esac
	done
	$bl_flash_cmd
}