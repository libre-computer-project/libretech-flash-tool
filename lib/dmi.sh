#!/usr/bin/env bash
## SPDX-License-Identifier: GPL-2.0
## Copyright (C) 2021 Da Xue <da@libre.computer>

DMI_LINUX_PATH=/sys/class/dmi/id
DMI_BOARD_VENDOR_get(){
	tr -d '\0' < $DMI_LINUX_PATH/board_vendor
}

DMI_BOARD_NAME_get(){
	tr -d '\0' < $DMI_LINUX_PATH/board_name
}


