# Libre Computer Flash Tool
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

./lft.sh bl-flash aml-s905x-cc
BOOTLOADER_get: downloading aml-s905x-cc bootloader to /tmp/tmp.qxl5vq5wBS.

--2022-09-02 23:44:39--  https://boot.libre.computer/ci/aml-s905x-cc
Resolving boot.libre.computer (boot.libre.computer)... 192.53.162.101, 2600:3c00::f03c:93ff:fea1:358c
Connecting to boot.libre.computer (boot.libre.computer)|192.53.162.101|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 851968 (832K) [application/octet-stream]
Saving to: ‘/tmp/tmp.qxl5vq5wBS’

/tmp/tmp.qxl5vq5wBS                100%[===============================================================>] 832.00K  4.77MB/s    in 0.2s    

2022-09-02 23:44:40 (4.77 MB/s) - ‘/tmp/tmp.qxl5vq5wBS’ saved [851968/851968]

BOOTLOADER_get: downloaded aml-s905x-cc bootloader to /tmp/tmp.qxl5vq5wBS.
BOOTLOADER_flash: dd if=/tmp/tmp.qxl5vq5wBS of=/dev/null oflag=sync bs=512 seek=1 status=progress
BOOTLOADER_flash: run the above command to flash the target device? (y/n)

dd if=/tmp/tmp.qxl5vq5wBS of=/dev/null oflag=sync bs=512 seek=1 status=progress
1664+0 records in
1664+0 records out
851968 bytes (852 kB, 832 KiB) copied, 0.00272618 s, 313 MB/s
BOOTLOADER_flash: bootloader written to null successfully.

```