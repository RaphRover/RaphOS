{ lib, pkgs, gptfdisk, util-linux, dosfstools, e2fsprogs, systemd }: ''
  disk=/dev/vda
  # Create partition table
  ${gptfdisk}/bin/sgdisk $disk \
      -n1:0:+100M -t1:ef00 -c1:esp \
      -n2:0:0 -t2:8300 -c2:root

  # Ensure that the partition block devices (/dev/vda1 etc) exist
  ${util-linux}/bin/partx -u "$disk"
  # Make a FAT filesystem for the EFI System Partition
  ${dosfstools}/bin/mkfs.vfat -F32 -n ESP "$disk"1
  # Make an ext4 filesystem for the system root
  ${e2fsprogs}/bin/mkfs.ext4 "$disk"2 -L root

  # Mount everything to /mnt and provide some directories needed later on
  mkdir /mnt
  ${util-linux}/bin/mount -t ext4 "$disk"2 /mnt
  mkdir -p /mnt/{proc,dev,sys,boot/efi}
  ${util-linux}/bin/mount -t vfat "$disk"1 /mnt/boot/efi
  ${util-linux}/bin/mount -o bind /proc /mnt/proc
  ${util-linux}/bin/mount -o bind /dev /mnt/dev
  ${util-linux}/bin/mount -t sysfs sysfs /mnt/sys

  # Make the Nix store available in /mnt, because that's where the .debs live.
  mkdir -p /mnt/inst${builtins.storeDir}
  ${util-linux}/bin/mount -o bind ${builtins.storeDir} /mnt/inst${builtins.storeDir}

  # Ubuntu Noble requires merged /usr directories scheme
  mkdir -p /mnt/usr/{bin,sbin,lib,lib64}
  ln -s /usr/bin /mnt/bin
  ln -s /usr/sbin /mnt/sbin
  ln -s /usr/lib /mnt/lib
  ln -s /usr/lib64 /mnt/lib64

  PATH=$PATH:${lib.makeBinPath [ pkgs.dpkg pkgs.glibc pkgs.xz ]}

  # Unpack the .debs.  We do this to prevent pre-install scripts
  # (which have lots of circular dependencies) from barfing.
  echo "unpacking Debs..."

  for deb in $debs; do
      if test "$deb" != "|"; then
      echo "$deb..."
      dpkg-deb --fsys-tarfile "$deb" | tar -x --keep-directory-symlink -C /mnt
      fi
  done

  # Now install the .debs.  This is basically just to register
  # them with dpkg and to make their pre/post-install scripts
  # run.
  echo "installing Debs..."

  export DEBIAN_FRONTEND=noninteractive
  chroot=$(type -tP chroot)

  debs_mnt=
  for deb in $debs; do
    debs_mnt="$debs_mnt /inst$deb";
  done

  PATH=/usr/bin:/bin:/usr/sbin:/sbin $chroot /mnt \
  dpkg --install --force-depends $debs_mnt < /dev/null

  # update-grub needs udev to detect the filesystem UUID -- without,
  # we'll get root=/dev/vda2 on the cmdline which will only work in
  # a limited set of scenarios.
  ${systemd}/lib/systemd/systemd-udevd &
  ${systemd}/bin/udevadm trigger
  ${systemd}/bin/udevadm settle

  chroot /mnt /bin/bash -exuo pipefail <<CHROOT
  export PATH=/usr/sbin:/usr/bin:/sbin:/bin

  # update-initramfs needs to know where its root filesystem lives,
  # so that the initial userspace is capable of finding and mounting it.
  echo LABEL=root / ext4 defaults > /etc/fstab

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

  # Set a password so we can log into the booted system
  echo root:root | chpasswd

  CHROOT

  ${util-linux}/bin/umount /mnt/inst${builtins.storeDir}
  ${util-linux}/bin/umount /mnt/boot/efi
  ${util-linux}/bin/umount /mnt/sys
  ${util-linux}/bin/umount /mnt/proc
  ${util-linux}/bin/umount /mnt/dev
  ${util-linux}/bin/umount /mnt
''
