#!/usr/bin/env bash -e

source $NIX_ATTRS_SH_FILE

DISK=/dev/vda

# Configuration
USER_NAME=raph
USER_PASS=raph
TARGET_HOSTNAME=raph

my_chroot() {
    DEBIAN_FRONTEND=noninteractive \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    $(type -tP chroot) $@
}

# Mount everything to /mnt and provide some directories needed later on
mkdir /mnt
mount -t ext4 "$DISK"2 /mnt
mkdir -p /mnt/{proc,dev,sys,boot/efi}
mount -t vfat "$DISK"1 /mnt/boot/efi
mount -o bind /proc /mnt/proc
mount -o bind /dev /mnt/dev
mount -o bind /dev/pts /mnt/dev/pts
mount -t sysfs sysfs /mnt/sys

# Remove redundant files
rm -rf /mnt/etc/update-motd.d/*

# Install configuration files
cp -vr --no-preserve=mode "${FILES_DIR}/"* /mnt/
cp -v /mnt/usr/share/systemd/tmp.mount /mnt/etc/systemd/system/

# Patch configuration files
sed -i "s|@USER_NAME@|${USER_NAME}|g" /mnt/etc/ros/setup.bash

# Fix file permissions
chmod +x /mnt/usr/lib/ros/*
chmod +x /mnt/etc/update-motd.d/*

# Symlink resolv.conf to systemd-resolved
ln -vsnf /lib/systemd/resolv.conf /mnt/etc/resolv.conf

# Remove SSH host keys
rm /mnt/etc/ssh/ssh_host_*

# Set hostname
echo "${TARGET_HOSTNAME}" > "/mnt/etc/hostname"
printf "\n127.0.1.1 ${TARGET_HOSTNAME}\n" >> "/mnt/etc/hosts"

# Configure nginx
rm -vf /mnt/etc/nginx/sites-enabled/default
ln -vs /etc/nginx/sites-available/raph_ui /mnt/etc/nginx/sites-enabled/raph_ui

my_chroot /mnt /bin/bash -exuo pipefail <<CHROOT
# Create default user
adduser --disabled-password --comment "" ${USER_NAME}

# Set the default user password
echo "${USER_NAME}:${USER_PASS}" | chpasswd

# Add the default user to different groups
for GRP in adm dialout audio sudo video plugdev input; do
    adduser $USER_NAME "\${GRP}"
done

# Change file ownership
chown ${USER_NAME}:${USER_NAME} -R "/etc/ros"
chown root:root -R "/etc/ros/rosdep"

# Do the rest of the commands as the default user
su - ${USER_NAME}
set -ex

# Enable user services
systemctl --user enable ros-nodes
systemctl --user enable uros-agent
systemctl --user enable ros.target
CHROOT

# Enable lingering for default user
mkdir -p -m 755 "/mnt/var/lib/systemd/linger"
touch "/mnt/var/lib/systemd/linger/${USER_NAME}"

# Automatically source our setup when user logs in to bash shell
echo -e "\nsource /etc/ros/setup.bash" >> "/mnt/home/${USER_NAME}/.bashrc"

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

# grub-mkconfig's auto-detection can still fail to resolve a UUID for the
# VM's root device and silently fall back to the raw device path (e.g.
# /dev/vda2), which won't exist on the real hardware. Rewrite every
# root= kernel argument already present in the generated config to use
# the actual filesystem UUID.
sed -i -E "s|root=[^ \"]+|root=UUID=${ROOT_UUID}|g" /mnt/boot/grub/grub.cfg

umount /mnt/boot/efi
umount /mnt/sys
umount /mnt/proc
umount /mnt/dev/pts
umount /mnt/dev
umount /mnt
