# Proxmox DietPi Automated Installer Guide

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
![Proxmox Version](https://img.shields.io/badge/Proxmox-7.x%2F8.x-orange)
![DietPi Version](https://img.shields.io/badge/DietPi-Bookworm%20x86__64-green)

A complete guide and automation script for deploying DietPi on Proxmox VE. Combines best practices from community knowledge and official documentation.

## 📋 Prerequisites

- Proxmox VE 7.x/8.x installed
- SSH access to Proxmox host
- Minimum resources:
  - 2GB RAM
  - 10GB storage
  - 2 CPU cores
- Network bridge configured (`vmbr0` default)

## 🚀 Quick Installation

### Manual Method (Single Pasteable Command)
```bash
VMID=100 && STORAGE=local-lvm && BRIDGE=vmbr0 && wget https://dietpi.com/downloads/images/DietPi_Proxmox-x86_64-Bookworm.qcow2.xz && xz -d DietPi_Proxmox-x86_64-Bookworm.qcow2.xz && qm create $VMID --name "DietPi" --memory 2048 --cores 2 --net0 virtio,bridge=$BRIDGE --scsihw virtio-scsi-pci && qm importdisk $VMID DietPi_Proxmox-x86_64-Bookworm.qcow2 $STORAGE && qm set $VMID --scsi0 $STORAGE:vm-$VMID-disk-0 --boot order=scsi0 --agent enabled=1 --ostype l26 && qm start $VMID
```

### Automated Script (`dietpi-install.sh`)

```bash
#!/bin/bash
# Auto-detects available VMID and storage
VMID=$(pvesh get /cluster/nextid)
STORAGE=$(pvesm status | grep active | awk '{print $1}' | head -1)
BRIDGE="vmbr0"

echo "Installing DietPi VM (ID: $VMID) on $STORAGE"

wget -q https://dietpi.com/downloads/images/DietPi_Proxmox-x86_64-Bookworm.qcow2.xz || {
  echo "Download failed"; exit 1
}

xz -d DietPi_Proxmox-x86_64-Bookworm.qcow2.xz || {
  echo "Decompression failed"; exit 1
}

qm create $VMID --name "DietPi" --memory 2048 --cores 2 --net0 virtio,bridge=$BRIDGE --scsihw virtio-scsi-pci && \
qm importdisk $VMID DietPi_Proxmox-x86_64-Bookworm.qcow2 $STORAGE && \
qm set $VMID --scsi0 $STORAGE:vm-$VMID-disk-0 --boot order=scsi0 --agent enabled=1 --ostype l26 && \
qm start $VMID || {
  echo "VM creation failed"; exit 1
}

echo "DietPi VM $VMID successfully created and started!"
```

## ⚙️ Configuration Options

| Parameter      | Description                          | Default Value   |
|----------------|--------------------------------------|-----------------|
| `VMID`         | Unique Proxmox VM identifier         | Auto-detected   |
| `STORAGE`      | Storage pool for disk image          | First active    |
| `BRIDGE`       | Network bridge interface             | vmbr0           |
| `MEMORY`       | RAM allocation (MB)                  | 2048            |
| `CORES`        | CPU core count                       | 2               |

## 🔧 Troubleshooting

### Common Issues

1. **"400 too many arguments" error**
   - Solution: Ensure correct storage format: `storage-name:vm-XX-disk-0`

2. **Boot failure after import**
   - Verify UEFI/BIOS settings match host configuration
   - Check disk visibility in Proxmox storage panel

3. **Network connectivity issues**
   ```bash
   qm set $VMID --delete net0 && \
   qm set $VMID --net0 virtio,bridge=$BRIDGE
   ```

## ❓ FAQ

**Q:** How do I change the VM ID?  
**A:** Set `VMID` variable before running script, or use `pvesh get /cluster/nextid` for next available ID

**Q:** Can I resize the disk later?  
**A:** Yes: `qm resize $VMID scsi0 +10G` (adds 10GB)

**Q:** How to access DietPi after installation?  
**A:** Use Proxmox console or SSH: `root@vm-ip` (password: `dietpi`)

## 📚 References

- [Official DietPi Proxmox Guide](https://dietpi.com/forum/t/guide-dietpi-on-proxmox/4931)
- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/Main_Page)
- [DietPi Configuration Tool](https://dietpi.com/docs/dietpi_tools/#dietpi-config)

## 📜 License

```text
MIT License
Copyright (c) [year] [your name]
```

*This project is not affiliated with DietPi or Proxmox GmbH*
