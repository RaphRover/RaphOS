#!/bin/sh -e

disk=/dev/vda
# Create partition table
sgdisk $disk \
    -n1:0:+100M -t1:ef00 -c1:esp \
    -n2:0:0 -t2:8300 -c2:root

# Ensure that the partition block devices (/dev/vda1 etc) exist
partx -u "$disk"
# Make a FAT filesystem for the EFI System Partition
mkfs.vfat -F32 -n ESP "$disk"1
# Make an ext4 filesystem for the system root
mkfs.ext4 "$disk"2 -L root

# Mount everything to /mnt and provide some directories needed later on
mkdir /mnt
mount -t ext4 "$disk"2 /mnt
mkdir -p /mnt/{proc,dev,sys,boot/efi}
mount -t vfat "$disk"1 /mnt/boot/efi
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

# Unpack the .debs.  We do this to prevent pre-install scripts
# (which have lots of circular dependencies) from barfing.
echo "unpacking Debs..."

echo ${debs_preunpack}

for deb in ${debs_preunpack}; do
    echo "$deb..."
    dpkg-deb --fsys-tarfile "$deb" | tar -x --keep-directory-symlink -C /mnt
done

# Now install the .debs.  This is basically just to register
# them with dpkg and to make their pre/post-install scripts
# run.
echo "installing Debs..."

# chroot /mnt /usr/sbin/update-passwd
# debs_mnt=
# for deb in $debs; do
#     debs_mnt="$debs_mnt /inst$deb";
# done

export DEBIAN_FRONTEND=noninteractive
# chroot=$(type -tP chroot)
# PATH=/usr/bin:/bin:/usr/sbin:/sbin $chroot /mnt \
# dpkg --install --force-depends $debs_mnt < /dev/null

oldIFS="$IFS"
IFS="|"
for component in $debs; do
    IFS="$oldIFS"
    echo
    echo ">>> INSTALLING COMPONENT: $component"
    debs=
    for i in $component; do
        debs="$debs /inst/$i";
    done

    # Create a fake start-stop-daemon script, as done in debootstrap.
    # mv "/mnt/sbin/start-stop-daemon" "/mnt/sbin/start-stop-daemon.REAL"
    # echo "#!/bin/true" > "/mnt/sbin/start-stop-daemon"
    # chmod 755 "/mnt/sbin/start-stop-daemon"

    chroot=$(type -tP chroot)
    PATH=/usr/bin:/bin:/usr/sbin:/sbin $chroot /mnt \
    apt-get install -y $debs < /dev/null

    # Move the real start-stop-daemon back into its place.
    # mv "/mnt/sbin/start-stop-daemon.REAL" "/mnt/sbin/start-stop-daemon"
done

# Copy configuration files
cp -v ${FILES_DIR}/fstab /mnt/etc/
cp -v ${FILES_DIR}/sources.list /mnt/etc/apt/
cp -v ${FILES_DIR}/systemd/ssh-generate-host-keys.service /mnt/etc/systemd/system/

# Remove SSH host keys
rm /mnt/etc/ssh/ssh_host_*

# update-grub needs udev to detect the filesystem UUID -- without,
# we'll get root=/dev/vda2 on the cmdline which will only work in
# a limited set of scenarios.
$UDEVD &
udevadm trigger
udevadm settle

chroot /mnt /bin/bash -exuo pipefail <<CHROOT
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

# actually generate an initramfs
update-initramfs -k all -c

# Install the boot loader to the EFI System Partition
# Remove "quiet" from the command line so that we can see what's happening during boot
cat >> /etc/default/grub <<EOF
GRUB_TIMEOUT=5
GRUB_CMDLINE_LINUX=""
GRUB_CMDLINE_LINUX_DEFAULT=""
EOF
sed -i '/TIMEOUT_HIDDEN/d' /etc/default/grub
update-grub
grub-install --target x86_64-efi

# Enable SSH server
systemctl enable ssh ssh-generate-host-keys

# Set a password so we can log into the booted system
echo root:root | chpasswd

CHROOT

umount /mnt/inst${NIX_STORE_DIR}
umount /mnt/boot/efi
umount /mnt/sys
umount /mnt/proc
umount /mnt/dev
umount /mnt