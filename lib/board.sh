#!/bin/bash
# SPDX-License-Identifier: CC-BY-NC-4.0
# Copyright (C) 2021 Da Xue <da@libre.computer>

declare -a BOARD_LIST=(
	"all-h3-cc-h3"
	"all-h3-cc-h5"
	"aml-s805x-ac"
	"aml-s905x-cc"
	"aml-s905x-cc-v2"
	"aml-s905d-pc"
	"roc-rk3328-cc"
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
	[aml-s805x-ac]=d0074000.mmc
	[aml-s905x-cc]=d0074000.mmc
	[aml-s905x-cc-v2]=d0074000.mmc
	[aml-s905d-pc]=d0074000.mmc
	[roc-rk3328-cc]=ff520000.mmc
	[roc-rk3399-pc]=fe320000.mmc
	)

declare -A BOARD_EMMC_DRIVER=(
	[all-h3-cc-h3]=sunxi-mmc
	[all-h3-cc-h5]=sunxi-mmc
	[aml-s805x-ac]=meson-gx-mmc
	[aml-s905x-cc]=meson-gx-mmc
	[aml-s905x-cc-v2]=meson-gx-mmc
	[aml-s905d-pc]=meson-gx-mmc
	[roc-rk3328-cc]=dwmmc_rockchip
	[roc-rk3399-pc]=dwmmc_rockchip
	)

BOARD_NAME_get(){
	if [ "$(DMI_BOARD_VENDOR_get)" != "libre-computer" ]; then
		echo "This command is designed for Libre Computer products." >&2
		exit 1 
	fi
	echo -n $(DMI_BOARD_NAME_get | tr "[:punct:]" " ") | tr -s ' ' '-' | tr '[:upper:]' '[:lower:]'
}

BOARD_DRIVER_PATH=/sys/bus/platform/drivers

BOARD_EMMC_isBound(){
	local board=${1:-$(BOARD_NAME_get)}
	[ -e "$BOARD_DRIVER_PATH/${BOARD_EMMC_DRIVER[$board]}/${BOARD_EMMC_DT_NODE[$board]}" ]
}

BOARD_EMMC_bind(){
	local board=${1:-$(BOARD_NAME_get)}
	BOARD_EMMC_isBound && return
	echo -n ${BOARD_EMMC_DT_NODE[$board]} > $BOARD_DRIVER_PATH/${BOARD_EMMC_DRIVER[$board]}/bind
}

BOARD_EMMC_unbind(){
	local board=$(BOARD_NAME_get)
	BOARD_EMMC_isBound && echo -n ${BOARD_EMMC_DT_NODE[$board]} > $BOARD_DRIVER_PATH/${BOARD_EMMC_DRIVER[$board]}/unbind
}

BOARD_EMMC_show(){
	echo "Not Implemented." >&2
}

BOARD_EMMC_test(){
	echo "Not Implemented." >&2
}
