#!/bin/bash

# Variables
VMID=100
STORAGE=local-lvm
BRIDGE=vmbr0
LXC_TEMPLATE_NAME="dietpi-lxc-template"
LXC_TEMPLATE_ID=200
DIETPI_IMAGE="DietPi_Proxmox-x86_64-Bookworm.qcow2"
DIETPI_IMAGE_XZ="${DIETPI_IMAGE}.xz"
LOCAL_TEMPLATE_STORAGE="/var/lib/vz/template/cache"

# Step 0: Install required dependencies
echo "Checking for and installing libguestfs-tools..."
if ! command -v guestmount &> /dev/null; then
    echo "libguestfs-tools not found. Installing..."
    apt update && apt install -y libguestfs-tools
    if [[ $? -ne 0 ]]; then
        echo "Failed to install libguestfs-tools. Exiting..."
        exit 1
    fi
else
    echo "libguestfs-tools is already installed."
fi

# Step 1: Check for existing files and delete them if found
echo "Checking for existing DietPi files..."
if [[ -f "$DIETPI_IMAGE" ]]; then
    echo "Found existing $DIETPI_IMAGE. Deleting..."
    rm -f "$DIETPI_IMAGE"
fi
if [[ -f "$DIETPI_IMAGE_XZ" ]]; then
    echo "Found existing $DIETPI_IMAGE_XZ. Deleting..."
    rm -f "$DIETPI_IMAGE_XZ"
fi

# Step 2: Download and prepare the DietPi image
echo "Downloading DietPi image..."
wget "https://dietpi.com/downloads/images/$DIETPI_IMAGE_XZ"
if [[ $? -ne 0 ]]; then
    echo "Failed to download DietPi image. Exiting..."
    exit 1
fi

echo "Extracting DietPi image..."
xz -d "$DIETPI_IMAGE_XZ"
if [[ $? -ne 0 ]]; then
    echo "Failed to extract DietPi image. Exiting..."
    exit 1
fi

# Step 3: Create a Proxmox VM
echo "Creating VM with ID $VMID..."
qm create $VMID --name "DietPi" --memory 2048 --cores 2 --net0 virtio,bridge=$BRIDGE --scsihw virtio-scsi-pci
qm importdisk $VMID "$DIETPI_IMAGE" $STORAGE
qm set $VMID --scsi0 $STORAGE:vm-$VMID-disk-0 --boot order=scsi0 --agent enabled=1 --ostype l26

# Step 4: Start the VM and wait for it to initialize
echo "Starting VM..."
qm start $VMID
echo "Waiting for VM to boot and initialize (2 minutes)..."
sleep 120

# Step 5: Stop the VM and prepare for conversion
echo "Stopping VM..."
qm stop $VMID

# Step 6: Mount the VM's disk and create a tarball of the root filesystem
echo "Mounting VM disk and creating tarball..."
DISK_PATH=$(pvesm path $STORAGE:vm-$VMID-disk-0)
mkdir -p /mnt/vmroot
guestmount -a $DISK_PATH -i /mnt/vmroot
tar -czvf /root/vm-rootfs.tar.gz -C /mnt/vmroot .
guestunmount /mnt/vmroot

# Step 7: Create an LXC container from the tarball
echo "Creating LXC container..."
pct create $LXC_TEMPLATE_ID /root/vm-rootfs.tar.gz --rootfs $STORAGE:8 --ostype unmanaged --hostname $LXC_TEMPLATE_NAME --storage $STORAGE --memory 1024 --swap 512 --cores 2 --password dietpi

# Step 8: Convert the LXC container to a template
echo "Converting LXC container to template..."
pct stop $LXC_TEMPLATE_ID
pct template $LXC_TEMPLATE_ID

# Step 9: Move the template to local CT template storage
echo "Moving LXC template to local storage..."
TEMPLATE_FILE=$(pct config $LXC_TEMPLATE_ID | grep rootfs | awk -F: '{print $2}' | awk '{print $1}')
TEMPLATE_NAME="${LXC_TEMPLATE_NAME}.tar.gz"
mv "$TEMPLATE_FILE" "${LOCAL_TEMPLATE_STORAGE}/${TEMPLATE_NAME}"

# Step 10: Cleanup
echo "Cleaning up..."
rm -f "$DIETPI_IMAGE"
rm -f /root/vm-rootfs.tar.gz

echo "Conversion complete! LXC template saved to: ${LOCAL_TEMPLATE_STORAGE}/${TEMPLATE_NAME}"
