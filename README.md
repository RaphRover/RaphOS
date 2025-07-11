# RaphOS
RaphOS is a Debian-based Operating System distribution for the single-board computer running inside Raph Rover (currently UP 7000). It uses Ubuntu and Fictionlab package archives, comes with a ROS distribution, preconfigured network, a desktop environment, a service for starting base functionalities at boot, and many more.

This repository contains a [Nix flake] for building RaphOS and bootstrapper images. \
The bootstrapper image is a minimal bootable NixOS iso image that, when booted, flashes the RaphOS image to the internal storage of the UP 7000. \
For the built bootstrapper images, visit the [Releases page](https://github.com/RaphRover/RaphOS/releases).

## Building
### Pre-requisites
* [Nix] with [Flakes] enabled
* AMD64 machine (the flake does not support cross-building yet)
* (optional) Hardware that supports [KVM] (e.g. Intel VT-x or AMD-V) for much faster builds due to hardware virtualization.

### Prepare the environment
Make sure `/dev/kvm` is available and the user has read/write access to it. \
You can check if KVM is available by running:
```bash
ls /dev/kvm
```
If it is not available, you may need to enable virtualization in the BIOS/UEFI settings.

You might also need to add your user to the `kvm` group to allow access to the KVM device:
```bash
sudo usermod -aG kvm $USER
```
Then, log out and log back in for the changes to take effect.

Also, make sure you have sufficient disk space available for the build. \
The bootstrapper image is around 4 GB, but the build process requires more space for intermediate [Nix derivations] outputs. \
At least 20 GB of free space is recommended.

### Build the image
To build the image, run the following command:
```bash
nix build -Lv
```
This will build the boostrapper image and place it in the `result` directory. \
The first time you run this command, it will take a while to build the image, as it will download all the dependencies. \
Subsequent builds will be faster, as Nix caches the dependencies.

To rebuild only the RaphOS image, you can run:
```bash
nix build -Lv .#OSImage
```

## Flashing the image
To flash the RaphOS image on the UP 7000, you first need to flash the bootstrapper image to a removable USB drive.
You can do this by running the following command, replacing `/dev/sdX` with the path to your USB drive (e.g. `/dev/sdb`):

**WARNING: This will erase all data (including partition table) on the selected USB drive!**

```bash
sudo dd if=RaphOS-bootstrapper-<version>.iso of=/dev/sdX bs=8K status=progress && sync
```

Alternatively, you can use programs like [balenaEtcher] to flash the boostrapper.

Connect the USB drive to the UP 7000 and turn it on. \
The UP 7000 should boot from the USB drive and start the flashing process. \
The flashing process will take a few minutes. There is currently no progress indicator, so just wait for aroung 5 minutes. \
After the flashing process is complete, unplug the USB drive and the UP 7000 will reboot automatically and start RaphOS.

[Nix flake]: https://nixos.wiki/wiki/Flakes
[Nix]: https://nixos.org/download.html
[Flakes]: https://nixos.wiki/wiki/Flakes
[KVM]: https://wiki.archlinux.org/title/KVM
[Nix derivations]: https://wiki.nixos.org/wiki/Derivations
[balenaEtcher]: https://etcher.balena.io
