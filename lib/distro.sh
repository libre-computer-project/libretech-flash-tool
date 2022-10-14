#!/bin/bash
# SPDX-License-Identifier: CC-BY-NC-4.0
# Copyright (C) 2021 Da Xue <da@libre.computer>

declare -A DISTRO_NAME=(
	[ubuntu]="Ubuntu"
	[raspbian]="Raspbian"
	)

declare -A DISTRO_UBUNTU_RELEASE=(
	[22.04]="Jammy Jellyfish"
	)
declare -A DISTRO_UBUNTU_RELEASE_PREFIX=(
	[22.04]="ubuntu-22.04.1-preinstalled-"
	)

declare -A DISTRO_RASPBIAN_RELEASE=(
	[11]="Bullseye"
	)

declare -A DISTRO_RASPBIAN_RELEASE_PREFIX=(
	[11]="2022-09-06-raspbian-bullseye-"
	)

DISTRO_URL="https://distro.libre.computer/ci"
DISTRO_SHA256SUM=SHA256SUMS

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
	echo "$FUNCNAME: downloading $url to $dist."
	echo
	wget -O - "$url" | xz -cd > $dist
	echo "$FUNCNAME: downloaded $url to $dist."
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
	if ! DISTRO_get "$url" $dist; then
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

	local dist_flash_cmd="dd if=$dist of=$dev_path bs=1M status=progress"

	if ! TOOLKIT_isInCaseInsensitive "force" "$@"; then
		echo "$FUNCNAME: $dist_flash_cmd" >&2
		echo "$FUNCNAME: run the above command to flash the target device?" >&2
		while true; do
			read -s -n 1 -p "(y/n)" confirm
			echo
			case "${confirm,,}" in
				y|yes)
					echo "$dist_flash_cmd"
					break
					;;
				n|no)
					echo "$FUNCNAME: operation cancelled." >&2
					return 1
					;;
			esac
		done
	fi

	if $dist_flash_cmd; then
		[ "$dev" = "null" ] || sync $dev_path
		echo "$FUNCNAME: distro written to $dev successfully." >&2
		if TOOLKIT_isInCaseInsensitive "verify" "$@"; then
			if cmp <(dd if=$dist bs=$dist_size count=1 2> /dev/null) \
					<(dd if=$dev_path bs=$dist_size count=1 2> /dev/null) > /dev/null; then
				echo "$FUNCNAME: distro written to $dev verified." >&2
			else
				echo "$FUNCNAME: distro written to $dev failed verification!" >&2
			fi
		fi
	else
		echo "$FUNCNAME: distro write to $dev failed!" >&2
		return 1
	fi
}