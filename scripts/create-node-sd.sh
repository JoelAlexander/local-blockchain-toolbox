#!/bin/bash
HOSTNAME=$1
PUB_KEY=$2
WIFI_SSID=$3
WIFI_PASSWORD=$4
NEW_USERNAME=$5

SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

IMAGE_URL="https://cdimage.ubuntu.com/releases/23.10/release/ubuntu-23.10-preinstalled-server-arm64+raspi.img.xz"
FILENAME=$LOCAL_DATA_DIR/ubuntu/$(basename $IMAGE_URL)
UNZIPPED_FILENAME="${FILENAME%.xz}"

select_sd_card() {
    echo "Detecting connected storage devices..."
    DEFAULT_DEVICE=$(lsblk -p | grep -E 'sd|mmcblk' | awk '{print $1}' | head -n 1)

    if [[ -z "$DEFAULT_DEVICE" ]]; then
        echo "No SD card devices detected."
        exit 1
    fi

    echo "Detected devices:"
    lsblk -p | grep -E 'sd|mmcblk'
    echo "The default device is $DEFAULT_DEVICE"

    read -p "Please enter the device path for the SD card [$DEFAULT_DEVICE]: " SD_CARD_DEVICE
    SD_CARD_DEVICE=${SD_CARD_DEVICE:-$DEFAULT_DEVICE}

    while [[ ! -e $SD_CARD_DEVICE ]]; do
        echo "Device not found. Please enter a valid device path:"
        read SD_CARD_DEVICE
        SD_CARD_DEVICE=${SD_CARD_DEVICE:-$DEFAULT_DEVICE}
    done

    echo "Selected SD card device: $SD_CARD_DEVICE"
}

if [[ -f "$UNZIPPED_FILENAME" ]]; then
    echo "The unzipped image file already exists. Skipping download and extraction."
else
	echo "Downloading Ubuntu Server image..."
    wget $IMAGE_URL -O $FILENAME
    echo "Unzipping the image..."
    xz -d $FILENAME
fi

select_sd_card

# Check for an existing boot partition
BOOT_PART_EXISTING=$(fdisk -l $SD_CARD_DEVICE | grep "W95 FAT32" | awk '{print $1}')
if [ ! -z "$BOOT_PART_EXISTING" ]; then
    read -p "An existing boot partition is found on $SD_CARD_DEVICE. Do you want to use it (y) or overwrite it with a new image (n)? " USE_EXISTING
    if [[ $USE_EXISTING == "y" ]]; then
        echo "Using the existing boot partition."
        BOOT_PART=$BOOT_PART_EXISTING
    fi
fi

if [[ $USE_EXISTING != "y" ]]; then
	read -p "Are you sure you want to write to $SD_CARD_DEVICE? This will erase all data on the device. (y/n): " CONFIRM
	if [[ $CONFIRM != "y" ]]; then
	    echo "Operation cancelled."
	    exit 1
	fi
	echo "Writing Ubuntu Server image to SD card. This may take a while..."
	dd bs=4M if="$UNZIPPED_FILENAME" of=$SD_CARD_DEVICE conv=fsync status=progress
	echo "Ubuntu Server image has been written to the SD card."
	BOOT_PART=$(fdisk -l $SD_CARD_DEVICE | grep "W95 FAT32" | awk '{print $1}')

	echo "Verifying the integrity of the flashed SD card..."
	BLOCK_SIZE=4194304 # 4M in bytes
	TOTAL_SIZE=$(stat -c%s "$UNZIPPED_FILENAME")
	NUM_BLOCKS=$(((TOTAL_SIZE / BLOCK_SIZE) + 1))
	dd bs=4M if=$SD_CARD_DEVICE of=/tmp/flashed_image.img count=$NUM_BLOCKS conv=fsync status=progress
	truncate -s $TOTAL_SIZE /tmp/flashed_image.img
	ACTUAL_FLASHED_CHECKSUM=$(sha256sum /tmp/flashed_image.img | awk '{print $1}')
	ORIGINAL_IMAGE_CHECKSUM=$(sha256sum $UNZIPPED_FILENAME | awk '{print $1}')

	if [ "$ACTUAL_FLASHED_CHECKSUM" != "$ORIGINAL_IMAGE_CHECKSUM" ]; then
	    echo "Integrity check failed. The SD card contents may be corrupted."
	    exit 1
	else
	    echo "Integrity check succeeded."
	    rm /tmp/flashed_image.img
	fi
fi

# Check if the boot volume is already mounted and find its mount point
if mount | grep -q "$BOOT_PART"; then
    echo "Boot volume is already mounted."
    MOUNT_POINT=$(mount | grep "$BOOT_PART" | awk '{print $3}')
    
    # Check if the mount is read-only
    if mount | grep "$BOOT_PART" | grep -q "ro,"; then
        echo "Boot volume is mounted as read-only. Remounting as read-write..."
        mount -o remount,rw $BOOT_PART $MOUNT_POINT
    fi
else
    echo "Mounting the boot volume..."
	MOUNT_POINT="/mnt/rpi-boot"
    mkdir -p $MOUNT_POINT
    mount $BOOT_PART $MOUNT_POINT
fi

# Before writing to network-config, check if it already exists and remove it
if [ -f "$MOUNT_POINT/network-config" ]; then
    rm "$MOUNT_POINT/network-config"
fi

cat <<EOF > $MOUNT_POINT/network-config
version: 2
ethernets:
    eth0:
        dhcp4: true
        optional: true
wifis:
    wlan0:
        dhcp4: true
        optional: true
        access-points:
            "$WIFI_SSID":
                password: "$WIFI_PASSWORD"
EOF

# Configure user-data with SSH key and disable password login
cat <<EOF > $MOUNT_POINT/user-data
#cloud-config
preserve_hostname: false
hostname: $HOSTNAME
manage_etc_hosts: true
users:
  - default
  - name: $NEW_USERNAME
    lock_passwd: true
    ssh_pwauth: False
    groups: sudo, users, admin, docker
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_import_id: None
    ssh-authorized-keys:
      - $PUB_KEY
packages:
  - avahi-daemon
  - certbot
  - docker.io
runcmd:
  - 'systemctl enable avahi-daemon'
EOF

# Unmount all partitions on SD_CARD_DEVICE
echo "Unmounting all partitions on $SD_CARD_DEVICE..."
for PART in $(mount | grep "$SD_CARD_DEVICE" | awk '{print $1}')
do
    echo "Unmounting $PART..."
    umount $PART
done

echo "All partitions on the SD card have been unmounted."
