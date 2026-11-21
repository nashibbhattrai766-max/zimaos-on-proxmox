# ZimaOS NAS as a Proxmox VM

[ZimaOS](https://github.com/IceWhaleTech/ZimaOS) running as a VM on Proxmox VE, serving a **RAID 1 mirror** on the two disks of a **Yottamaster 2-bay USB enclosure** passed through to the VM. It hosts SMB shares, the Immich photo library, Jellyfin and other Docker apps from the ZimaOS app store.

## Layout

| | |
|---|---|
| VM | 4 vCPU, 8–12 GB RAM, 120 GB system disk on the node's NVMe |
| Data | Yottamaster 2-bay USB enclosure → passed through to the VM → RAID 1 mirror (`md`), ~5.5 TB usable |
| Apps | Immich, Jellyfin, node-exporter, photo backup container |
| Backups | VM disk: nightly to Proxmox Backup Server. Photo library: [immich-pbs-backup](https://github.com/nashibbhattrai766-max/immich-pbs-backup) |

## Notes and fixes

### QEMU guest agent
ZimaOS is a read-only appliance (Buildroot) with no package manager, so you can't `apt install qemu-guest-agent`. It does include the `qemu-ga` binary, though — it just has no service. [`qemu-guest-agent.service`](qemu-guest-agent.service) adds one. After installing it and enabling the agent in Proxmox (full stop/start, not a reboot, so the virtio channel is created), Proxmox shows the VM's IP and shuts it down cleanly.

Check before you start that the kernel has the driver: `ls /sys/bus/virtio/drivers` must list `virtio_console`.

### Memory
Without the agent, Proxmox counts the guest's page cache as "used", so a NAS always looks 90–95 % full. Compare with `free -h` inside ZimaOS (look at *available*). With Immich's machine-learning container and Jellyfin, 8 GB was genuinely tight (repeated >90 % alerts); 12 GB gives headroom.

### USB enclosure start order
The VM must not start before the USB disks are visible, or ZimaOS comes up without its RAID. Instead of *Start at boot*, a small systemd unit on the Proxmox node waits for the enclosure's disks and then starts the VM. On shutdown a second unit "parks" the enclosure after the guests have stopped. Some JMicron-based enclosures also need the UAS driver disabled with a `usb-storage` quirk (see the [backup server notes](https://github.com/nashibbhattrai766-max/proxmox-backup-server) for the same fix).

### Useful commands (inside ZimaOS)
```bash
sudo -i                                   # most admin work needs root; /DATA isn't writable otherwise
cat /proc/mdstat                          # RAID state
df -h /media/*                            # volumes
docker stats --no-stream                  # per-app CPU/RAM
```

## License

MIT
