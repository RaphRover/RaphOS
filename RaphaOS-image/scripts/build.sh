#!/bin/sh -e

my_chroot() {
    DEBIAN_FRONTEND=noninteractive \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    $(type -tP chroot) $@
}

DISK=/dev/vda
# Create partition table
sgdisk $DISK \
    -n1:0:+100M -t1:ef00 -c1:esp \
    -n2:0:0 -t2:8300 -c2:root

# Ensure that the partition block devices (/dev/vda1 etc) exist
partx -u "$DISK"
# Make a FAT filesystem for the EFI System Partition
mkfs.vfat -F32 -n ESP "$DISK"1
# Make an ext4 filesystem for the system root
mkfs.ext4 "$DISK"2 -L root

# Mount everything to /mnt and provide some directories needed later on
mkdir /mnt
mount -t ext4 "$DISK"2 /mnt
mkdir -p /mnt/{proc,dev,sys,boot/efi}
mount -t vfat "$DISK"1 /mnt/boot/efi
mount -o bind /proc /mnt/proc
mount -o bind /dev /mnt/dev
mount -t sysfs sysfs /mnt/sys

# Make the Nix store available in /mnt, because that's where the .debs live.
mkdir -p /mnt/inst${NIX_STORE_DIR}
mount -o bind ${NIX_STORE_DIR} /mnt/inst${NIX_STORE_DIR}

# Ubuntu Noble requires merged /usr directories scheme
mkdir -p /mnt/usr/{bin,sbin,lib,lib64}
ln -s /usr/bin /mnt/bin
ln -s /usr/sbin /mnt/sbin
ln -s /usr/lib /mnt/lib
ln -s /usr/lib64 /mnt/lib64

echo "Preunpacking Debs..."

for deb in ${debs_preunpack}; do
    echo "$deb..."
    dpkg-deb --extract "$deb" /mnt
done

echo "installing Debs..."

oldIFS="$IFS"
IFS="|"
for component in $debs; do
    IFS="$oldIFS"
    echo
    echo ">>> INSTALLING COMPONENT: $component"
    debs=
    for i in $component; do
        debs="$debs /inst$i";
    done

    my_chroot /mnt apt-get install -y $debs < /dev/null
done

# Install configuration files
cp -vr "${FILES_DIR}/etc" /mnt/

# Symlink resolv.conf to systemd-resolved
ln -vsnf /lib/systemd/resolv.conf /mnt/etc/resolv.conf

# Remove SSH host keys
rm /mnt/etc/ssh/ssh_host_*

# update-grub needs udev to detect the filesystem UUID -- without,
# we'll get root=/dev/vda2 on the cmdline which will only work in
# a limited set of scenarios.
$UDEVD &
udevadm trigger
udevadm settle

my_chroot /mnt /bin/bash -exuo pipefail <<CHROOT
# Install the boot loader to the EFI System Partition
update-grub
grub-install --target x86_64-efi

# Enable SSH server
systemctl enable ssh ssh-generate-host-keys

# Enable Networkd
systemctl enable systemd-networkd

# Set a password so we can log into the booted system
echo root:root | chpasswd

CHROOT

umount /mnt/inst${NIX_STORE_DIR}
umount /mnt/boot/efi
umount /mnt/sys
umount /mnt/proc
umount /mnt/dev
umount /mnt