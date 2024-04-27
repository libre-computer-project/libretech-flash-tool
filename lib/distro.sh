#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2024 Da Xue <da@libre.computer>

declare -A DISTRO_NAME=(
	[debian]="Debian"
	[raspbian]="Raspbian"
	[ubuntu]="Ubuntu"
	)

declare -A DISTRO_DEBIAN_RELEASE=(
	[11]="Bullseye"
	[12]="Bookworm"
	)

declare -A DISTRO_DEBIAN_RELEASE_PREFIX=(
	[11]="debian-11-"
	[12]="debian-12-"
	)

declare -A DISTRO_RASPBIAN_RELEASE=(
	[10]="Buster"
	[11]="Bullseye"
	[12]="Bookworm"
	)

declare -A DISTRO_RASPBIAN_RELEASE_PREFIX=(
	[10]="2023-05-03-raspbian-buster-"
	[11]="2023-05-03-raspbian-bullseye-"
	[12]="2023-10-10-raspbian-bookworm-"
	)

declare -A DISTRO_UBUNTU_RELEASE=(
	[20.04]="Focal Fossa"
	[22.04]="Jammy Jellyfish"
	[24.04]="Noble Numbat"
	)

declare -A DISTRO_UBUNTU_RELEASE_PREFIX=(
	[20.04]="ubuntu-20.04.5-preinstalled-"
	[22.04]="ubuntu-22.04.3-preinstalled-"
	[24.04]="ubuntu-24.04-preinstalled-"
	)

DISTRO_URL="https://distro.libre.computer/ci"
DISTRO_SHA256SUM=SHA256SUMS

DISTRO_LEFT_URL="https://distro.libre.computer/left/left-uefi.img.xz"
DISTRO_LEFT_SHA256SUM_URL="https://distro.libre.computer/left/SHA256SUMS"

DISTRO_getURL(){
	local distro=$1
	local release=$2
	shift 2
	echo -n $DISTRO_URL/$distro/$release/$@
}

DISTRO_getSHA256SUMS(){
	wget -O - $(DISTRO_getURL $1 $2 $DISTRO_SHA256SUM) 2> /dev/null
}

DISTRO_get(){
	local url=$1
	local dist=$2
	echo "$FUNCNAME: downloading $url to $dist"
	echo
	#TODO: check download size vs mountpoint free space
	#TODO: direct write to disk with checksum verify if low space
	wget -O $dist "$url"
	echo "$FUNCNAME: downloaded $url to $dist."
	local checksum=$(sha256sum $dist | cut -f 1 -d ' ')
	if [ ! -z "$3" ]; then
		if [ "$checksum" != "$3" ]; then
			echo "$FUNCNAME: checksum $checksum does not match expected $3"
			return 1
		fi
		echo "$FUNCNAME: checksum verified."
	fi
}

DISTRO_list(){
	if [ -z "$1" ]; then
		for distro_name in "${DISTRO_NAME[@]}"; do
			echo $distro_name
		done
		return
	elif [ ! -v "DISTRO_NAME[$1]" ]; then
		echo "$FUNCNAME: DISTRO $distro is not supported." >&2
		return 1
	fi
	local distro="$1"
	shift
	local distro_release="DISTRO_${distro^^}_RELEASE"
	declare -n distro_release="$distro_release"
	if [ -z "$1" ]; then
		for release in "${!distro_release[@]}"; do
			echo $release ${distro_release[$release]}
		done
		return
	elif [ ! -v "distro_release[$1]" ]; then
		echo "$FUNCNAME: DISTRO RELEASE $distro $release is not supported." >&2
		return 1
	fi
	local release="$1"
	local distro_release_prefix="DISTRO_${distro^^}_RELEASE_PREFIX"
	declare -n distro_release_prefix="$distro_release_prefix"
	local release_prefix="${distro_release_prefix[$release]}"
	shift
	local sha256sums=$(DISTRO_getSHA256SUMS $distro $release)
	if [ $? -eq 1 ]; then
		echo "$FUNCNAME: DISTRO RELEASE $distro $release manifest retreival failed." >&2
		return 1
	fi
	local variants=$(echo "$sha256sums" | sed "s/^.*$release_prefix//" | sed -E "s/-?arm(hf|64)-?//" | sed "s/+.*.img.[gx]z//" | sed "s/^$/desktop/" | sort | uniq)
	if [ -z "$variants" ]; then
		echo "$FUNCNAME: DISTRO RELEASE $distro $release variants are not available." >&2
		return 1
	fi
	if [ -z "$1" ]; then
		echo "$variants"
		return
	fi
	local variant_found=0
	for variant_name in $variants; do
		if [ "$variant_name" = "$1" ]; then
			local variant_found=1
			local variant="$1"
			shift
			break
		fi
	done
	if [ "$variant_found" -eq 0 ]; then
		echo "$FUNCNAME: DISTRO RELEASE VARIANT $distro $release $variant is not available." >&2
		return 1
	fi
	local boards=$(echo "$sha256sums" | sed "s/^.*$release_prefix//" | sed -E "s/-?arm(hf|64)-?//" | sed "s/.img.[gx]z//" | sed "s/^+/desktop+/" | grep "$variant" | sed "s/$variant//" | sed "s/+//" )
	if [ -z "$1" ]; then
		echo "$boards"
		return
	fi
	local board_found=0
	for board_name in $boards; do
		if [ "$board_name" = "$1" ]; then
			local board_found=1
			local board="$1"
			shift
			break
		fi
	done
	if [ "$board_found" -eq 0 ]; then
		echo "$FUNCNAME: DISTRO RELEASE VARIANT BOARD $distro $release $variant $board is not available." >&2
		return 1
	fi
	if [ "$distro" = "raspbian" -a "$variant" = "desktop" ]; then
		local row=$(echo "$sha256sums" | grep "$release_prefix" | grep -v "\\-lite" | grep "+$board.img.[gx]z" | tac -s ' ')
	else
		local row=$(echo "$sha256sums" | grep "$release_prefix" | grep "$variant" | grep "+$board.img.[gx]z" | tac -s ' ')
	fi
	if [ $? -ne 0 ]; then
		echo "$FUNCNAME: Internal error. Please submit a bug report!" >&2
		return 1
	fi
	echo -n $(DISTRO_getURL $distro $release $row)
}

DISTRO_flash(){
	local url_checksum=($(DISTRO_list $@))
	local url=${url_checksum[0]}
	local checksum=${url_checksum[1]}
	shift 4

	traps_start
	local dist=$(mktemp)
	traps_push rm $dist

	local dev=$1
	shift

	local dev_path=/dev/$dev

	if ! BLOCK_DEV_isValid $dev; then
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

	if ! WGET_getHeaders "$url" > $dist; then
		if grep -io "HTTP/1.1\s404\sNot\sFound" $dist > /dev/null; then
			echo "$FUNCNAME: DISTRO could not be found at $url." >&2
		else
			echo "$FUNCNAME: DISTRO server could not be reached." >&2
		fi
		return 1
	fi

	#local dist_size=$(grep -oi "Content-Length:\s\+[0-9]*" $dist | tail -n 1 | tr -s " " | cut -f 2 -d " ")
	#if [ "$dist_size" -lt $((100*1024*1024)) ]; then
	#	echo "$FUNCNAME: DISTRO size is unexpectedly small." >&2
	#	return 1
	#fi

	if ! DISTRO_get "$url" $dist $checksum; then
		echo "$FUNCNAME: DISTRO could not be downloaded." >&2
		return 1
	fi

	#if [ $(stat -c %s $dist) -ne $dist_size ]; then
	#	echo "$FUNCNAME: DISTRO does not match expected size." >&2
	#	return 1
	#fi
	local dist_size=$(stat -c %s $dist)

	if BLOCK_DEV_isMounted $dev; then
		echo "$FUNCNAME: !!!WARNING!!! DEVICE $dev is mounted." >&2
	fi

	local dist_flash_cmd="xz -cd $dist | dd of=$dev_path bs=1M iflag=fullblock oflag=dsync status=progress"

	if ! TOOLKIT_isInCaseInsensitive "force" "$@"; then
		echo "$FUNCNAME: $dist_flash_cmd" >&2
		echo "$FUNCNAME: run the above command to flash the target device?" >&2
		if TOOLKIT_promptYesNo; then
			echo "$dist_flash_cmd"
		else
			echo "$FUNCNAME: operation cancelled." >&2
			return 1
		fi
	fi

	local dist_flash_bytes=$(eval "$dist_flash_cmd 2>&1 | tee /dev/stderr | grep -oE '^[0-9]+ bytes' | tail -n 1 | cut -f 1 -d ' '")
	if [ $? -eq 0 ]; then
		[ "$dev" = "null" ] || sync $dev_path
		echo "$FUNCNAME: distro written to $dev successfully." >&2
		if [ -z "$dist_flash_bytes" ]; then
			echo "$FUNCNAME: unable to determine decompressed size." >&2
			return 1
		elif TOOLKIT_isInCaseInsensitive "verify" "$@"; then
			if [ "$dev" = "null" ]; then
				echo "$FUNCNAME: null device cannot be verified." >&2
				return 1
			fi
			if cmp -n $dist_flash_bytes <(xz -cd $dist 2> /dev/null) $dev_path > /dev/null; then
				echo "$FUNCNAME: distro written to $dev verified." >&2
				traps_popUntilLength 0
				traps_stop
			else
				echo "$FUNCNAME: distro written to $dev failed verification!" >&2
				return 1
			fi
		else
			traps_popUntilLength 0
			traps_stop
		fi
	else
		echo "$FUNCNAME: distro write to $dev failed!" >&2
		return 1
	fi
}

DISTRO_flashLEFT(){
	set -x
	local url_checksum=($(DISTRO_list $@))
	local url=${url_checksum[0]}
	local checksum=${url_checksum[1]}
	shift 4

	traps_start
	local left=$(mktemp)
	traps_push rm $left

	local dist=$(mktemp)
	traps_push rm $dist

	local dev=$1
	shift

	local dev_path=/dev/$dev

	if ! BLOCK_DEV_isValid $dev; then
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

	if ! WGET_getHeaders "$DISTRO_LEFT_URL" > $left; then
		if grep -io "HTTP/1.1\s404\sNot\sFound" $dist > /dev/null; then
			echo "$FUNCNAME: LEFT could not be found at $url." >&2
		else
			echo "$FUNCNAME: LEFT server could not be reached." >&2
		fi
	fi

	if ! WGET_getHeaders "$url" > $dist; then
		if grep -io "HTTP/1.1\s404\sNot\sFound" $dist > /dev/null; then
			echo "$FUNCNAME: DISTRO could not be found at $url." >&2
		else
			echo "$FUNCNAME: DISTRO server could not be reached." >&2
		fi
		return 1
	fi

	#local dist_size=$(grep -oi "Content-Length:\s\+[0-9]*" $dist | tail -n 1 | tr -s " " | cut -f 2 -d " ")
	#if [ "$dist_size" -lt $((100*1024*1024)) ]; then
	#	echo "$FUNCNAME: DISTRO size is unexpectedly small." >&2
	#	return 1
	#fi

	#TODO left checksum
	if ! DISTRO_get "$DISTRO_LEFT_URL" $left; then
		echo "$FUNCNAME: DISTRO could not be downloaded." >&2
		return 1
	fi

	#if [ $(stat -c %s $dist) -ne $dist_size ]; then
	#	echo "$FUNCNAME: DISTRO does not match expected size." >&2
	#	return 1
	#fi
	local dist_size=$(stat -c %s $dist)

	if BLOCK_DEV_isMounted $dev; then
		echo "$FUNCNAME: !!!WARNING!!! DEVICE $dev is mounted." >&2
	fi

	local left_flash_cmd="xz -cd $left | dd of=$dev_path bs=1M iflag=fullblock oflag=dsync status=progress"

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
		local left_part_dir=$(mktemp -d)
		traps_push rmdir "$left_part_dir"
		mount "$left_part_path" "$left_part_dir"
		traps_push umount "$left_part_dir"
		local left_distro_filename="${url##*/}"
		if ! DISTRO_get "$url" "$left_part_dir/$left_distro_filename" $checksum; then
			echo "$FUNCNAME: DISTRO could not be downloaded." >&2
			return 1
		fi
		echo "IMAGE_FILE=$left_distro_filename" > "$left_part_dir/flash.ini"
		echo "$FUNCNAME: DISTRO written to $dev$(BLOCK_DEV_getPartPrefix $dev_path)$left_part_num successfully." >&2
		traps_popUntilLength 0
		traps_stop
	else
		echo "$FUNCNAME: LEFT write to $dev failed!" >&2
		return 1
	fi
}
