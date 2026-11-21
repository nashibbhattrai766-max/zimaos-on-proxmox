#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# Writes NAS drive SMART data for node-exporter. Skips drives that are asleep.
DIR=/var/lib/prometheus/node-exporter
OUT=$DIR/nas_smart.prom; TMP=$OUT.tmp
{
echo "# TYPE nas_disk_temp_celsius gauge"
echo "# TYPE nas_disk_health_ok gauge"
echo "# TYPE nas_disk_power_on_hours gauge"
echo "# TYPE nas_disk_bad_sectors gauge"
for d in /dev/disk/by-id/ata-WDC_*; do
  [[ $d == *-part* ]] && continue
  j=$(smartctl -d sat -n standby -j -i -A -H "$d" 2>/dev/null)
  model=$(jq -r '.model_name // empty' <<<"$j"); [ -z "$model" ] && continue
  serial=$(jq -r '.serial_number' <<<"$j")
  L="disk=\"${model#WDC }\",serial=\"$serial\""
  echo "nas_disk_temp_celsius{$L} $(jq '.temperature.current // 0' <<<"$j")"
  echo "nas_disk_health_ok{$L} $(jq 'if (.smart_status.passed // true) then 1 else 0 end' <<<"$j")"
  echo "nas_disk_power_on_hours{$L} $(jq '.power_on_time.hours // 0' <<<"$j")"
  echo "nas_disk_bad_sectors{$L} $(jq '[.ata_smart_attributes.table[]? | select(.id==5 or .id==197 or .id==198) | .raw.value] | add // 0' <<<"$j")"
done
} > $TMP && mv $TMP $OUT
