#!/bin/bash
for i in $(seq 1 90); do
  n=$(ls /dev/disk/by-id/ 2>/dev/null | grep -E '^ata-WDC_WD60' | grep -vc part)
  if [ "$n" -ge 2 ]; then
    qm status 500 | grep -q running || qm start 500
    echo "NAS drives found, VM 500 started"; exit 0
  fi
  sleep 10
done
echo "NAS drives not found after 15 min"; exit 1

