#!/bin/bash
# Set variables
VMID=$(pvesh get /cluster/nextid)
STORAGE=$(pvesm status | grep active | awk '{print $1}' | head -1)
BRIDGE="vmbr0"

# Download and decompress image
wget https://dietpi.com/downloads/images/DietPi_Proxmox-x86_64-Bookworm.qcow2.xz
xz -d DietPi_Proxmox-x86_64-Bookworm.qcow2.xz

# Configure VM
qm create $VMID --name "DietPi" --memory 2048 --cores 2 --net0 virtio,bridge=$BRIDGE
qm importdisk $VMID DietPi_Proxmox-x86_64-Bookworm.qcow2 $STORAGE
qm set $VMID --scsihw virtio-scsi-pci --scsi0 $STORAGE:vm-$VMID-disk-0 --boot order=scsi0
qm start $VMID
