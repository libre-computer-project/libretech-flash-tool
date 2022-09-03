# Libre Computer Flash Tool
## Objective
Quickly deploy bootloaders and images to MicroSD or eMMC storage mediums destined for Libre Computer boards.

## Warning
This tool writes to raw blocks to the target device. Precautions such as 
avoiding root target device have been implemented. However, it is impossible
to account for all scenarios. Before this tool executes writes, it will
display the write command to be executed. Please review it carefully before
confirming the action. Some bootloaders will clobber the GPT entries at the
beginning of the disk. Other bootloaders will write beyond the 1MB starting
point for most partition tools. Make sure you know what you are doing! If the
device you are trying to flash holds important data, back it up before using
this tool! This is your first and only warning.

## How to Use
```bash
git clone https://github.com/libre-computer-project/libretech-flash-tool.git
cd libretech-flash-tool

./lft.sh bl-list
aml-s905x-cc-v2
aml-s905x-cc
all-h3-cc-h5
all-h3-cc-h3
aml-s805x-ac
roc-rk3399-pc
roc-rk3328-cc

./lft.sh dev-list
sdb

sudo ./lft.sh bl-flash aml-s905x-cc sdb
BOOTLOADER_get: downloading aml-s905x-cc bootloader to /tmp/tmp.otrZBzPL4o.

--2022-09-02 23:48:50--  https://boot.libre.computer/ci/aml-s905x-cc
Resolving boot.libre.computer (boot.libre.computer)... 192.53.162.101, 2600:3c00::f03c:93ff:fea1:358c
Connecting to boot.libre.computer (boot.libre.computer)|192.53.162.101|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 851968 (832K) [application/octet-stream]
Saving to: ‘/tmp/tmp.otrZBzPL4o’

/tmp/tmp.otrZBzPL4o              100%[=======================================================>] 832.00K  3.45MB/s    in 0.2s    

2022-09-02 23:48:50 (3.45 MB/s) - ‘/tmp/tmp.otrZBzPL4o’ saved [851968/851968]

BOOTLOADER_get: downloaded aml-s905x-cc bootloader to /tmp/tmp.otrZBzPL4o.
BOOTLOADER_flash: dd if=/tmp/tmp.otrZBzPL4o of=/dev/sdb oflag=sync bs=512 seek=1 status=progress
BOOTLOADER_flash: run the above command to flash the target device?
(y/n)
dd if=/tmp/tmp.otrZBzPL4o of=/dev/sdb oflag=sync bs=512 seek=1 status=progress
815616 bytes (816 kB, 796 KiB) copied, 2 s, 407 kB/s
1664+0 records in
1664+0 records out
851968 bytes (852 kB, 832 KiB) copied, 2.09354 s, 407 kB/s
BOOTLOADER_flash: bootloader written to sdb successfully.
```