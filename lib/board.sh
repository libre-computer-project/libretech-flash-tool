#!/bin/bash
# SPDX-License-Identifier: CC-BY-NC-4.0
# Copyright (C) 2021 Da Xue <da@libre.computer>

declare -a BOARD_LIST=(
	"all-h3-cc-h3"
	"all-h3-cc-h5"
	"aml-s805x-ac"
	"aml-s905x-cc"
	"aml-s905x-cc-v2"
	"roc-rk3328-cc"
	"roc-rk3399-pc"
	)

BOARD_list(){
	local _board
	for _board in ${BOARD_LIST[@]}; do
		echo $_board
	done
}