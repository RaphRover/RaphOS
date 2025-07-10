#!/bin/sh -e

# Configuration
USER_NAME=raph
USER_PASS=raph
TARGET_HOSTNAME=raph

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
mount -o bind /dev/pts /mnt/dev/pts
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

DEBS_STAGE0_FILES=$(cat ${debsStage0})
DEBS_STAGE1_FILES=$(cat ${debsStage1})

echo "Unpacking predependencies..."

for deb in ${DEBS_STAGE0_FILES}; do
    [ "$deb" = "|" ] && continue
    echo "$deb..."
    dpkg-deb --extract "$deb" /mnt
done

echo "Installing Debs..."

oldIFS="$IFS"
IFS="|"
for component in ${DEBS_STAGE0_FILES} ${DEBS_STAGE1_FILES}; do
    IFS="$oldIFS"
    echo
    echo ">>> INSTALLING COMPONENT: $component"
    debs=
    for i in $component; do
        debs="$debs /inst$i";
    done

    my_chroot /mnt dpkg --install $debs < /dev/null
done

# Remove redundant files
rm -rf /mnt/etc/update-motd.d/*

# Install configuration files
cp -vr --no-preserve=mode "${FILES_DIR}/"* /mnt/
cp -v /mnt/usr/share/systemd/tmp.mount /mnt/etc/systemd/system/

# Fix file permissions
chmod +x /mnt/etc/update-motd.d/*

# Symlink resolv.conf to systemd-resolved
ln -vsnf /lib/systemd/resolv.conf /mnt/etc/resolv.conf

# Remove SSH host keys
rm /mnt/etc/ssh/ssh_host_*

# Set hostname
echo "${TARGET_HOSTNAME}" > "/mnt/etc/hostname"
printf "\n127.0.1.1 ${TARGET_HOSTNAME}\n" >> "/mnt/etc/hosts"

my_chroot /mnt /bin/bash -exuo pipefail <<CHROOT
# Create default user
adduser --disabled-password --comment "" ${USER_NAME}

# Set the default user password
echo "${USER_NAME}:${USER_PASS}" | chpasswd

# Add the default user to different groups
for GRP in adm dialout audio sudo video plugdev input; do
    adduser $USER_NAME "\${GRP}"
done
CHROOT

# update-grub needs udev to detect the filesystem UUID -- without,
# we'll get root=/dev/vda2 on the cmdline which will only work in
# a limited set of scenarios.
$UDEVD &
udevadm trigger
udevadm settle

my_chroot /mnt /bin/bash -exuo pipefail <<CHROOT
# Create initramfs
update-initramfs -c -k all

# Update GRUB configuration
update-grub

# Install the GRUB bootloader to the EFI System Partition
grub-install --target x86_64-efi

# Enable SSH server
systemctl enable ssh ssh-generate-host-keys

# Enable Networkd
systemctl enable systemd-networkd

# Enable tmpfs on /tmp
systemctl enable tmp.mount
CHROOT

# Remove backup files
find "/mnt/etc" -type f -name "*-" -exec rm -v {} \;
find "/mnt/var" -type f -name "*-old" -exec rm -v {} \;

# Truncate all logs
find "/mnt/var/log/" -type f -exec cp -v /dev/null {} \;

# Clear up /run directory
rm -v -rf "/mnt/run/"*

umount /mnt/inst${NIX_STORE_DIR}
umount /mnt/boot/efi
umount /mnt/sys
umount /mnt/proc
umount /mnt/dev/pts
umount /mnt/dev
umount /mnt