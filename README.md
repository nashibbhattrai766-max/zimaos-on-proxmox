# ZimaOS NAS as a Proxmox VM

[ZimaOS](https://github.com/IceWhaleTech/ZimaOS) running as a VM on Proxmox VE, serving a **RAID 1 mirror** on the two disks of a **Yottamaster 2-bay USB enclosure** passed through to the VM. It hosts SMB shares, the Immich photo library, Jellyfin and other Docker apps from the ZimaOS app store.

## Layout

| | |
|---|---|
| VM | 4 vCPU, 8–12 GB RAM, 120 GB system disk on the node's NVMe |
| Data | Yottamaster 2-bay USB enclosure (JMicron JMS56x) with 2× WD 6 TB → passed through to the VM → RAID 1 mirror (`md`), ~5.5 TB usable |
| Apps | Immich, Jellyfin, node-exporter, photo backup container |
| Backups | VM disk: nightly to Proxmox Backup Server. Photo library: [immich-pbs-backup](https://github.com/nashibbhattrai766-max/immich-pbs-backup) |

## Notes and fixes

### QEMU guest agent
ZimaOS is a read-only appliance (Buildroot) with no package manager, so you can't `apt install qemu-guest-agent`. It does include the `qemu-ga` binary, though — it just has no service. [`qemu-guest-agent.service`](qemu-guest-agent.service) adds one. After installing it and enabling the agent in Proxmox (full stop/start, not a reboot, so the virtio channel is created), Proxmox shows the VM's IP and shuts it down cleanly.

Check before you start that the kernel has the driver: `ls /sys/bus/virtio/drivers` must list `virtio_console`.

### Memory
Without the agent, Proxmox counts the guest's page cache as "used", so a NAS always looks 90–95 % full. Compare with `free -h` inside ZimaOS (look at *available*). With Immich's machine-learning container and Jellyfin, 8 GB was genuinely tight (repeated >90 % alerts); 12 GB gives headroom.

### USB enclosure: the host-side scripts
The enclosure is a 2-bay unit with a **JMicron JMS56x** USB bridge (`152d:0565`) holding two **WD 6 TB** drives. Getting it stable took four small pieces on the Proxmox node, all in [`host/`](host/):

| File | Install to | What it does |
|---|---|---|
| [`jmicron-no-uas.conf`](host/jmicron-no-uas.conf) | `/etc/modprobe.d/` | Forces the plain `usb-storage` driver instead of UAS. With UAS this bridge reset under load and dropped the RAID. Run `update-initramfs -u` and reboot. |
| [`50-usb-autosuspend.rules`](host/50-usb-autosuspend.rules) | `/etc/udev/rules.d/` | Stops Linux putting the enclosure to sleep (USB autosuspend), which also caused disconnects. |
| [`start-nas-when-ready.sh`](host/start-nas-when-ready.sh) + [`start-nas.service`](host/start-nas.service) | `/usr/local/bin/`, `/etc/systemd/system/` | After a node boot, waits up to 15 minutes until **both** WD disks are visible, then starts the NAS VM. The VM therefore does **not** use *Start at boot*. Starting before the disks appear brought ZimaOS up with a degraded or missing RAID. |
| [`nas-usb-park.sh`](host/nas-usb-park.sh) + [`nas-usb-park.service`](host/nas-usb-park.service) | same | On node shutdown, **after** the guests have stopped, flushes and detaches both disks and de-authorises the USB device, so the drives park their heads cleanly instead of losing power mid-write. |
| [`nas-smart.sh`](host/nas-smart.sh) + [`nas-smart.cron`](host/nas-smart.cron) | `/usr/local/bin/`, `/etc/cron.d/` | Every 5 minutes reads SMART data (temperature, health, power-on hours, bad sectors) and writes it as Prometheus metrics for the NAS rack screen. Uses `-n standby` so it never wakes sleeping disks. |

```bash
cp host/*.sh /usr/local/bin/ && chmod +x /usr/local/bin/{start-nas-when-ready,nas-usb-park,nas-smart}.sh
cp host/*.service /etc/systemd/system/ && systemctl daemon-reload
systemctl enable start-nas nas-usb-park && systemctl start nas-usb-park   # "start" arms the stop hook
cp host/jmicron-no-uas.conf /etc/modprobe.d/ && update-initramfs -u
cp host/50-usb-autosuspend.rules /etc/udev/rules.d/
cp host/nas-smart.cron /etc/cron.d/nas-smart
qm set 500 --onboot 0      # the service starts the VM instead
```
Edit the VM ID (500), the disk pattern (`ata-WDC_WD60*`) and the USB IDs to match yours.

### Useful commands (inside ZimaOS)
```bash
sudo -i                                   # most admin work needs root; /DATA isn't writable otherwise
cat /proc/mdstat                          # RAID state
df -h /media/*                            # volumes
docker stats --no-stream                  # per-app CPU/RAM
```

## License

MIT
