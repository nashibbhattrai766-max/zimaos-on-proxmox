#!/bin/bash
pgrep -f -- "-id 500 " >/dev/null && exit 0
sync
for l in /dev/disk/by-id/ata-WDC_WD60*; do
  case "$l" in *-part*) continue;; esac
  d=$(basename "$(readlink -f "$l")"); echo 1 > /sys/block/$d/device/delete 2>/dev/null
done
sleep 2
for u in /sys/bus/usb/devices/*; do
  [ "$(cat $u/idVendor 2>/dev/null)" = 152d ] && [ "$(cat $u/idProduct 2>/dev/null)" = 0565 ] && echo 0 > $u/authorized
done
exit 0
