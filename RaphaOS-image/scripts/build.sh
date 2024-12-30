#!/bin/sh -e

# Configuration
FIRST_USER_NAME=ibis
FIRST_USER_PASS=ibis
TARGET_HOSTNAME=ibis

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

echo "Unpacking Debs..."

DEBS_UNPACK_FILES=$(cat ${debs_unpack})

for deb in ${DEBS_UNPACK_FILES}; do
    echo "$deb..."
    dpkg-deb --extract "$deb" /mnt
done

echo "Installing Debs..."

DEBS_INSTALL_FILES=$(cat ${debs_install})

oldIFS="$IFS"
IFS="|"
for component in ${DEBS_INSTALL_FILES}; do
    IFS="$oldIFS"
    echo
    echo ">>> INSTALLING COMPONENT: $component"
    debs=
    for i in $component; do
        debs="$debs /inst$i";
    done

    my_chroot /mnt dpkg --install --force-conflicts --force-overwrite $debs < /dev/null
done

# Install configuration files
cp -vr --no-preserve=mode "${FILES_DIR}/"* /mnt/
cp -v /mnt/usr/share/systemd/tmp.mount /mnt/etc/systemd/system/

# Fix file permissions
chmod +x /mnt/usr/lib/ros/*

# Symlink resolv.conf to systemd-resolved
ln -vsnf /lib/systemd/resolv.conf /mnt/etc/resolv.conf

# Remove SSH host keys
rm /mnt/etc/ssh/ssh_host_*

# Set hostname
echo "${TARGET_HOSTNAME}" > "/mnt/etc/hostname"
printf "\n127.0.1.1 ${TARGET_HOSTNAME}\n" >> "/mnt/etc/hosts"

my_chroot /mnt /bin/bash -exuo pipefail <<CHROOT
# Create default user
if ! id -u ${FIRST_USER_NAME} >/dev/null 2>&1; then
	adduser --disabled-password --gecos "" ${FIRST_USER_NAME}
fi
echo "${FIRST_USER_NAME}:${FIRST_USER_PASS}" | chpasswd
for GRP in adm dialout audio sudo video plugdev input; do
    adduser $FIRST_USER_NAME "\${GRP}"
done

# Build IBIS packages
su - ${FIRST_USER_NAME}
cd /home/ibis
mkdir -p ros_ws/src
cp -vr /inst${ibis_ros_src}/. ros_ws/src/ibis_ros
cd ros_ws
source /opt/ros/jazzy/setup.bash
colcon build --symlink-install --event-handlers desktop_notification- status- terminal_title-

# Enable user services
systemctl --user enable ros-nodes
systemctl --user enable uros-agent
CHROOT

# Enable lingering for default user
mkdir -p -m 755 "/mnt/var/lib/systemd/linger"
touch "/mnt/var/lib/systemd/linger/${FIRST_USER_NAME}"

# Automatically source our setup when user logs in to bash shell
echo -e "\nsource /etc/ros/setup.bash" >> "/mnt/home/${FIRST_USER_NAME}/.bashrc"

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

umount /mnt/inst${NIX_STORE_DIR}
umount /mnt/boot/efi
umount /mnt/sys
umount /mnt/proc
umount /mnt/dev/pts
umount /mnt/dev
umount /mnt