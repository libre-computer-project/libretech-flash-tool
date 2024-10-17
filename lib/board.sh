#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2021 Da Xue <da@libre.computer>

declare -a BOARD_LIST=(
	"all-h3-cc-h3"
	"all-h3-cc-h5"
	"aml-a311d-cc-v01"
	"aml-a311d-cc"
	"aml-s805x-ac"
	"aml-s905x-cc"
	"aml-s905x-cc-v2"
	"aml-s905d-pc"
	"aml-s905d3-cc-v01"
	"aml-s905d3-cc"
	"roc-rk3328-cc"
	"roc-rk3328-cc-v2"
	"roc-rk3399-pc"
	)

BOARD_list(){
	local _board
	for _board in ${BOARD_LIST[@]}; do
		echo $_board
	done
}

declare -A BOARD_EMMC_DT_NODE=(
	[all-h3-cc-h3]=1c11000.mmc
	[all-h3-cc-h5]=1c11000.mmc
	[aml-a311d-cc-v01]=ffe07000.mmc
	[aml-a311d-cc]=ffe07000.mmc
	[aml-s805x-ac]=d0074000.mmc
	[aml-s905x-cc]=d0074000.mmc
	[aml-s905x-cc-v2]=d0074000.mmc
	[aml-s905d-pc]=d0074000.mmc
	[aml-s905d3-cc-v01]=ffe07000.mmc
	[aml-s905d3-cc]=ffe07000.mmc
	[roc-rk3328-cc]=ff520000.mmc
	[roc-rk3328-cc-v2]=ff520000.mmc
	[roc-rk3399-pc]=fe320000.mmc
	)

declare -A BOARD_EMMC_DRIVER=(
	[all-h3-cc-h3]=sunxi-mmc
	[all-h3-cc-h5]=sunxi-mmc
	[aml-a311d-cc-v01]=meson-gx-mmc
	[aml-a311d-cc]=meson-gx-mmc
	[aml-s805x-ac]=meson-gx-mmc
	[aml-s905x-cc]=meson-gx-mmc
	[aml-s905x-cc-v2]=meson-gx-mmc
	[aml-s905d-pc]=meson-gx-mmc
	[aml-s905d3-cc-v01]=meson-gx-mmc
	[aml-s905d3-cc]=meson-gx-mmc
	[roc-rk3328-cc]=dwmmc_rockchip
	[roc-rk3328-cc-v2]=dwmmc_rockchip
	[roc-rk3399-pc]=dwmmc_rockchip
	)

BOARD_NAME_get(){
	if [ "$(DMI_BOARD_VENDOR_get)" != "libre-computer" ]; then
		echo "This command is designed for Libre Computer products." >&2
		exit 2
	fi
	local board=$(echo -n $(DMI_BOARD_NAME_get | tr "[:punct:]" " ") | tr -s ' ' '-' | tr '[:upper:]' '[:lower:]')

	while [ -z "${BOARD_EMMC_DRIVER[$board]}" ]; do
		local board_new="${board%-*}"
		if [ -z "$board_new" ] || [ "$board_new" = "$board" ]; then
			echo "$FUNCNAME: BOARD $1 is not supported" >&2
			return 1
		fi
		local board="$board_new"
	done
	echo -n $board
}

BOARD_DRIVER_PATH=/sys/bus/platform/drivers

BOARD_EMMC_isBound(){
	local board=${1:-$(BOARD_NAME_get)}
	if [ -z "$board" ]; then
		return 2
	fi
	[ -e "$BOARD_DRIVER_PATH/${BOARD_EMMC_DRIVER[$board]}/${BOARD_EMMC_DT_NODE[$board]}" ]
}

BOARD_EMMC_bind(){
	local board=${1:-$(BOARD_NAME_get)}
	if [ -z "$board" ]; then
		return 2
	fi
	if BOARD_EMMC_isBound $board; then
		echo "$FUNCNAME: eMMC already bound." >&2
		return 1
	fi
	local driver_bind=$BOARD_DRIVER_PATH/${BOARD_EMMC_DRIVER[$board]}/bind
	if [ ! -w "$driver_bind" ]; then
		echo "$FUNCNAME: eMMC write permission denied." >&2
		return 1
	fi
	echo -n ${BOARD_EMMC_DT_NODE[$board]} > $driver_bind
}

BOARD_EMMC_unbind(){
	local board=$(BOARD_NAME_get)
	if [ -z "$board" ]; then
		return 2
	fi
	if ! BOARD_EMMC_isBound $board; then
		echo "$FUNCNAME: eMMC not bound." >&2
		return 1
	fi
	local driver_unbind=$BOARD_DRIVER_PATH/${BOARD_EMMC_DRIVER[$board]}/unbind
	if [ ! -w "$driver_unbind" ]; then
		echo "$FUNCNAME: eMMC write permission denied." >&2
		return 1
	fi
	echo -n ${BOARD_EMMC_DT_NODE[$board]} > $driver_unbind
}

BOARD_EMMC_rebind(){
	local board=$(BOARD_NAME_get)
	if [ -z "$board" ]; then
		return 2
	fi
	if BOARD_EMMC_isBound $board; then
		BOARD_EMMC_unbind $board
	fi
	sleep 1
	BOARD_EMMC_bind $board
}

BOARD_EMMC_show(){
	echo "Not Implemented." >&2
}

BOARD_EMMC_test(){
	echo "Not Implemented." >&2
}
BOARD_BOOTROM_USB_drive(){
	if [ -z "$1" ]; then
		echo "$FUNCNAME: Board required." >&2
		return 2
	fi
	if [ ! -z "$2" ]; then
		if [ "${2,,}" != "emmc" ]; then
			echo "$FUNCNAME: Only eMMC drive mode is implemented." >&2
			return 2
		fi
	fi
	local board=$1
	case $board in
		roc-rk3328-*)
			local usb_device=2207:320c
			local soc_vendor=rockchip
			local soc_tool="bin/rockusb-$(uname -m) download-boot"
			local soc_tool_canfail=1
			;;
		roc-rk3399-*)
			local soc_vendor=rockchip
			local usb_device=2207:330c
			local soc_tool="bin/rockusb-$(uname -m) download-boot"
			local soc_tool_canfail=0
			;;
		*)
			echo "$FUNCNAME: Board $board is not supported." >&2
			return 2
			;;
	esac
	local usb_device_list=$(lsusb -d $usb_device)
	if [ -z "$usb_device_list" ]; then
		echo "$FUNCNAME: No USB devices found matching $usb_device." >&2
		return 1
	fi

	traps_start
	local bl=$(mktemp)
	local bl_wget_log=$(mktemp)
	traps_push rm "$bl" "$bl_wget_log"

	if ! wget -O "$bl" "$BOOTLOADER_URL/$board-ums-emmc" 2> "$bl_wget_log"; then
		cat $bl_wget_log
		if grep -io "404\sNot\sFound" $bl_wget_log > /dev/null; then
			echo "$FUNCNAME: BOARD $board bootloader could not be found." >&2
		else
			echo "$FUNCNAME: BOARD $board bootloader server could not be reached." >&2
		fi
		return 1
	fi
	vendor/$soc_vendor/$soc_tool "$bl" || [ "$soc_tool_canfail" -eq 1 ]
	traps_popUntilLength 0
	traps_stop
	echo "Please wait a minute for the board to enumerate the ${2,,} as a USB drive or an ACM debug device if the ${2,,} cannot be enumerated as a USB drive."
}
