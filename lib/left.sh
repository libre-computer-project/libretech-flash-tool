#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2022 Da Xue <da@libre.computer>

LEFT_URL="https://distro.libre.computer/left/left-uefi.img.xz"
LEFT_SHA256SUM_URL="https://distro.libre.computer/left/SHA256SUMS"

# board dev image param
LEFT_flash(){
	local dev=$1
	shift

	local dev_path=/dev/$dev

	local image=$1
	shift

	traps_start
	local left=$(mktemp)
	traps_push rm $left

	if ! BLOCK_DEV_isValid $dev; then
		echo "$FUNCNAME: DEVICE $dev is not a valid target." >&2
		return 1
	fi

	if BLOCK_DEV_isMounted $dev; then
		echo "$FUNCNAME: !!!ERROR!!! DEVICE $dev is mounted." >&2
		return 1
	fi

	if [ ! -w "$dev_path" ]; then
		echo "$FUNCNAME: DEVICE $dev is not writable by current user $USER." >&2
		return 1
	fi

	if [ ! -z "$image" ] && [ ! -f "$image" ]; then
		echo "$FUNCNAME: IMAGE $image does not exist." >&2
		return 1
	fi

	if ! WGET_getHeaders "$LEFT_URL" > $left; then
		if grep -io "HTTP/1.1\s404\sNot\sFound" $dist > /dev/null; then
			echo "$FUNCNAME: LEFT could not be found at $url." >&2
		else
			echo "$FUNCNAME: LEFT server could not be reached." >&2
		fi
	fi

	#local dist_size=$(grep -oi "Content-Length:\s\+[0-9]*" $dist | tail -n 1 | tr -s " " | cut -f 2 -d " ")
	#if [ "$dist_size" -lt $((100*1024*1024)) ]; then
	#	echo "$FUNCNAME: DISTRO size is unexpectedly small." >&2
	#	return 1
	#fi

	#TODO left checksum
	if ! DISTRO_get "$LEFT_URL" $left; then
		echo "$FUNCNAME: DISTRO could not be downloaded." >&2
		return 1
	fi

	#if [ $(stat -c %s $dist) -ne $dist_size ]; then
	#	echo "$FUNCNAME: DISTRO does not match expected size." >&2
	#	return 1
	#fi
	#local dist_size=$(stat -c %s $dist)

	if BLOCK_DEV_isMounted $dev; then
		echo "$FUNCNAME: !!!ERROR!!! DEVICE $dev is mounted." >&2
		return 1
	fi

	local left_flash_cmd="xz -cd $left | dd of=$dev_path bs=1M iflag=fullblock oflag=dsync conv=notrunc status=progress"

	if ! TOOLKIT_isInCaseInsensitive "force" "$@"; then
		echo "$FUNCNAME: $left_flash_cmd" >&2
		echo "$FUNCNAME: run the above command to flash the target device?" >&2
		if TOOLKIT_promptYesNo; then
			echo "$left_flash_cmd"
		else
			echo "$FUNCNAME: operation cancelled." >&2
			return 1
		fi
	fi

	local left_flash_bytes=$(eval "$left_flash_cmd 2>&1 | tee /dev/stderr | grep -oE '^[0-9]+ bytes' | tail -n 1 | cut -f 1 -d ' '")
	if [ $? -eq 0 ]; then
		[ "$dev" = "null" ] || sync $dev_path
		echo "$FUNCNAME: LEFT written to $dev successfully." >&2
		if [ -z "$left_flash_bytes" ]; then
			echo "$FUNCNAME: unable to determine decompressed size." >&2
			return 1
		elif TOOLKIT_isInCaseInsensitive "verify" "$@"; then
			if [ "$dev" = "null" ]; then
				echo "$FUNCNAME: null device cannot be verified." >&2
				return 1
			fi
			if cmp -n $left_flash_bytes <(xz -cd $left 2> /dev/null) $dev_path > /dev/null; then
				echo "$FUNCNAME: LEFT written to $dev verified." >&2
			else
				echo "$FUNCNAME: LEFT written to $dev failed verification!" >&2
				return 1
			fi
		fi
		# DOWNLOAD
		partprobe "$dev_path"
		local left_end=$(parted -m "$dev_path" unit s print | tail -n 1 | cut -f 3 -d : | grep -oE [0-9]+)
		local left_parted_cmd="parted $dev_path mkpart primary ext4 $((left_end+1))s 100%"
		echo "$FUNCNAME: $left_parted_cmd" >&2
		echo "$FUNCNAME: run the above command to partition the target device?" >&2
		if TOOLKIT_promptYesNo; then
			echo "$left_parted_cmd"
			eval "$left_parted_cmd"
		else
			echo "$FUNCNAME: operation cancelled." >&2
			return 1
		fi
		partprobe "$dev_path"
		local left_part_num=$(parted -m "$dev_path" unit s print | tail -n 1 | cut -f 1 -d :)
		local left_part_path="${dev_path}$(BLOCK_DEV_getPartPrefix $dev_path)${left_part_num}"
		mkfs.ext4 -F "$left_part_path"
		if [ ! -z "$image" ]; then 
			local left_part_dir=$(mktemp -d)
			traps_push rmdir "$left_part_dir"
			mount "$left_part_path" "$left_part_dir"
			traps_push umount "$left_part_dir"
			local left_distro_filename="${image##*/}"
			dd if="$image" of="$left_part_dir/$left_distro_filename" bs=1M oflag=sync status=progress
			echo "IMAGE_FILE=$left_distro_filename" > "$left_part_dir/flash.ini"
			if [ ! -z "$LEFT_IMAGE_EXPAND" ]; then
				echo "IMAGE_EXPAND=1" >> "$left_part_dir/flash.ini"
			fi
			echo "$FUNCNAME: IMAGE written to $dev$(BLOCK_DEV_getPartPrefix $dev_path)$left_part_num successfully." >&2
		else
			echo "$FUNCNAME: LEFT setup on $dev$(BLOCK_DEV_getPartPrefix $dev_path)$left_part_num successfully." >&2
		fi
		traps_popUntilLength 0
		traps_stop
	else
		echo "$FUNCNAME: LEFT write to $dev failed!" >&2
		return 1
	fi
}
