#!/usr/bin/env bash -e

source $NIX_ATTRS_SH_FILE

# Configuration
USER_NAME=raph
VNC_PASSWORD=fictionlab

my_chroot() {
    env -i \
    DEBIAN_FRONTEND=noninteractive \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    $(type -tP chroot) $@
}

DISK=/dev/vda

# Mount everything to /mnt and provide some directories needed later on
mkdir /mnt
mount -t ext4 "$DISK"2 /mnt
mkdir -p /mnt/{proc,dev,sys,boot/efi}
mount -t vfat "$DISK"1 /mnt/boot/efi
mount -o bind /proc /mnt/proc
mount -o bind /dev /mnt/dev
mount -o bind /dev/pts /mnt/dev/pts
mount -t sysfs sysfs /mnt/sys

# Install configuration files
cp -vr --no-preserve=mode "${FILES_DIR}/"* /mnt/

# Patch configuration files
sed -i "s|Clearlooks|Lubuntu Arc|g" /mnt/etc/xdg/openbox/rc.xml

# Fix file permissions
chmod +x /mnt/etc/lightdm/headless-res.sh

# Disable autostart applications
echo "Hidden=true" >> /mnt/etc/xdg/autostart/lxqt-powermanagement.desktop

# Set VNC password for x0vncserver
echo "$VNC_PASSWORD" | my_chroot /mnt vncpasswd -f > /mnt/etc/x0vncserver.passwd

# Enable x0vncserver service
my_chroot /mnt systemctl enable x0vncserver

# Unmount everything
umount /mnt/boot/efi
umount /mnt/sys
umount /mnt/proc
umount /mnt/dev/pts
umount /mnt/dev
umount /mnt
