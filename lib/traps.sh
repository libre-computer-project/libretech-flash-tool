#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Da Xue

TRAPS_DEBUG=0
TRAPS_SIGNAL=EXIT

declare -a TRAPS_PARAMS
declare -a TRAPS_LENGTHS
TRAPS_LENGTH=

function traps_start {
	if [ -z "$TRAPS_LENGTH" ]; then
		TRAPS_LENGTH=0
		if [ "$TRAPS_SIGNAL" = "ERR" ]; then
			trap 'traps_exit $LINENO ${#FUNCNAME[@]} "${BASH_SOURCE[@]}" "${BASH_LINENO[@]}" "${FUNCNAME[@]}"' $TRAPS_SIGNAL
		else
			trap traps_exit $TRAPS_SIGNAL
		fi
	else
		if [ "$TRAPS_DEBUG" -eq 1 ]; then
			echo "$FUNCNAME: duplicate call" >&2
		fi
		return 1
	fi
}

function traps_isEmpty {
	if [ -z "$TRAPS_LENGTH" ]; then
		if [ "$TRAPS_DEBUG" -eq 1 ]; then
			echo "$FUNCNAME: traps not started" >&2
		fi
		return 2
	fi
	if [ $TRAPS_LENGTH -gt 0 ]; then
		return 1
	fi
	return 0
}

function traps_push {
	if [ -z "$TRAPS_LENGTH" ]; then
		if [ "$TRAPS_DEBUG" -eq 1 ]; then
			echo "$FUNCNAME: traps not started" >&2
		fi
		return 1
	fi
	TRAPS_PARAMS+=("$@")
	TRAPS_LENGTHS+=($#)
	((TRAPS_LENGTH=TRAPS_LENGTH+1))
}

function traps_pop {
	if [ -z "$TRAPS_LENGTH" ]; then
		if [ "$TRAPS_DEBUG" -eq 1 ]; then
			echo "$FUNCNAME: traps not started" >&2
		fi
		return 1
	elif [ $TRAPS_LENGTH -gt 0 ]; then
		local trap_length=${TRAPS_LENGTHS[@]: -1}
		local trap_cmd=("${TRAPS_PARAMS[@]: -$trap_length}")
		local traps_params_end=$((${#TRAPS_PARAMS[@]}-trap_length))
		TRAPS_PARAMS=("${TRAPS_PARAMS[@]:0:$traps_params_end}")
		TRAPS_LENGTH=$((TRAPS_LENGTH-1))
		TRAPS_LENGTHS=(${TRAPS_LENGTHS[@]:0:$TRAPS_LENGTH})
		if [ "$TRAPS_DEBUG" -eq 1 ]; then
			echo "$FUNCNAME: ${trap_cmd[@]}" >&2
		fi
		"${trap_cmd[@]}"
	else
		if [ "$TRAPS_DEBUG" -eq 1 ]; then
			echo "$FUNCNAME: traps empty" >&2
		fi
		return 1
	fi
}

function traps_popUntilLength {
	if [ -z "$TRAPS_LENGTH" ]; then
		if [ "$TRAPS_DEBUG" -eq 1 ]; then
			echo "$FUNCNAME: traps not started" >&2
		fi
		return 1
	elif [ "$1" -gt $TRAPS_LENGTH ]; then
		echo "$FUNCNAME: traps length below target" >&2
		return 1
	fi
	while [ "$TRAPS_LENGTH" -gt "$1" ]; do
		traps_pop
	done
}

function traps_drop {
	if [ -z "$TRAPS_LENGTH" ]; then
		if [ "$TRAPS_DEBUG" -eq 1 ]; then
			echo "$FUNCNAME: traps not started" >&2
		fi
		return 1
	elif [ $TRAPS_LENGTH -gt 0 ]; then
		local trap_length=${TRAPS_LENGTHS[@]: -1}
		local traps_params_end=$((${#TRAPS_PARAMS[@]}-trap_length))
		TRAPS_PARAMS=("${TRAPS_PARAMS[@]:0:$traps_params_end}")
		TRAPS_LENGTH=$((TRAPS_LENGTH-1))
		TRAPS_LENGTHS=(${TRAPS_LENGTHS[@]:0:$TRAPS_LENGTH})
	else
		if [ "$TRAPS_DEBUG" -eq 1 ]; then
			echo "$FUNCNAME: traps empty" >&2
		fi
		return 1
	fi
}


function traps_stop {
	if [ "$TRAPS_LENGTH" = "0" ]; then
		TRAPS_LENGTH=
		trap - $TRAPS_SIGNAL
	else
		if [ "$TRAPS_DEBUG" -eq 1 ]; then
			echo "$FUNCNAME: registered traps" >&2
			traps_diag >&2
		fi
		return 1
	fi
}

function traps_cancel {
	if [ -z "$TRAPS_LENGTH" ]; then
		if [ "$TRAPS_DEBUG" -eq 1 ]; then
			echo "$FUNCNAME: traps not started" >&2
		fi
		return 1
	fi
	TRAPS_PARAMS=()
	TRAPS_LENGTHS=()
	TRAPS_LENGTH=
	trap - $TRAPS_SIGNAL
}

function traps_exit {
	if [ "$TRAPS_DEBUG" -eq 1 ] && [ "$TRAPS_SIGNAL" = "ERR" ]; then
		local IFS=' '
		trap "traps_exit_now ${*@Q}" EXIT
	else
		trap - $TRAPS_SIGNAL
	fi
	if [ -z "$TRAPS_LENGTH" ]; then
		if [ "$TRAPS_DEBUG" -eq 1 ]; then
			echo "$FUNCNAME: traps not initiated" >&2
		fi
		return 1
	fi
	while [ "$TRAPS_LENGTH" -gt 0 ]; do
		traps_pop
	done
	return 1
}

function traps_exit_now {
	echo "$FUNCNAME: $TRAPS_SIGNAL in $3 line $1" >&2
	local i=1
	while [ $i -lt $2 ]; do
		local i_func=$(($2*2+$i+2))
		local i_file=$(($i+3))
		local i_line=$(($2+$i+2))
		echo "$FUNCNAME: trace: ${@:$i_func:1} in ${@:$i_file:1} line ${@:$i_line:1}" >&2
		local i=$((i+1))
	done
}

function traps_diag {
	echo "$FUNCNAME params: ${TRAPS_PARAMS[@]}"
	echo "$FUNCNAME lengths: ${TRAPS_LENGTHS[@]}"
	echo "$FUNCNAME length: $TRAPS_LENGTH"
}
