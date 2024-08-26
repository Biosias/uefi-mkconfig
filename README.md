# uefi-mkconfig
grub-mkconfig inspired script for automatically managing uefi entries.

## Goals
The goal of this script is to utilise direct kernel booting feature of UEFI firmware to remove the need for using bootloaders and make the process as simple as possible at the same time.

## Warning!
uefi-mkconfig uses UEFI Firmware to do things like setting boot order and creating boot entries.
However implementations of UEFI Firmware were shown to not be very standardised and firmware of some hardware vendors can exhibit quirky behaviour.

We try to mitigate these behaviours as they are discovered and reported to us.
However because of low age of this project we can't guarantee that all quirks were mitigated.
If you find some, please report it to us as soon as possible.

**Because of this fact, we strongly recommend testing your firmware if it works correctly with uefi-mkconfig before using it in the production environment!**

These quirks are more common the older the hardware is.

## Setup
After installation there are few steps that need to be taken before uefi-mkconfig can be used:

### 1. Install the dependencies
uefi-mkconfig uses the following programs:
* Bash,
* efibootmgr,
* GNU Core Utilities,
* util-linux,
* GNU Find Utilities.

### 2. Verify boot partition type
uefi-mkconfig uses the `lsblk` command to identify which mounted partitions are EFI partitions.

Because of this, all EFI partitions need to be of a correct partition type (Partition type EFI System).

Following is an example of how to verify this:

```console
# lsblk -o +PARTTYPE,PARTTYPENAME
NAME                                          MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINTS
                                                                                PARTTYPE                             PARTTYPENAME
nvme0n1                                       259:0    0 500G  0 disk
├─nvme0n1p1                                   259:1    0     1G  0 part  /boot  c12a7328-f81f-11d2-ba4b-00a0c93ec93b EFI System
```

### 3. Create configuration file
The configuration file should be an ordinary text file named `uefi-mkconfig` located in one of following directories:

* `/etc/default/`,
* `/etc/kernel/`,
* `/usr/lib/kernel/`.

### 4. Add kernel commands
This configuration file should contain **only** space separated list of kernel commands which should be used for creating UEFI booting entries.
For example:

```console
# cat /etc/default/uefi-mkconfig
crypt_root=UUID=dcb0cc6f-ddac-ge38-b92c-e59edc55dv61 root=/dev/mapper/gentoo rootfstype=ext4 resume=/dev/mapper/swap dolvm quiet
```

In case this configuration file doesn't exist, uefi-mkconfig will refuse to run.

### 5. Add all EFI partitions to fstab
uefi-mkconfig autodiscovers kernel images by searching all mounted EFI partitions.
This means that having all EFI partitions you want to use, mounted upon running uefi-mkconfig is paramount.
If they are not, the script will refuse to run.
If only some of them are mounted, **you will loose** entries for kernel images located on said unmounted partitions.

Because of this, adding all EFI partitions, you want to use, into the `/etc/fstab` file is **strongly** recommended.

## Features

### 1. Automatic UEFI Entry Management
uefi-mkconfig uses efibootmgr to create and delete EFI entries for directly booting linux kernels.

Automatic management is limited to range `0100`-`0200` Boot IDs in the UEFI Firmware.
These IDs are hexadecimal numbers, so there are 256 slots which are managed automatically.

If you need to add custom entry please add it outside of this range.
This will ensure that uefi-mkconfig will not touch your manually added entry.

### 2. Kernel Auto-Discovery
uefi-mkconfig searches through all mounted EFI partitions and creates EFI entries for all (not ignored) kernel images it finds.

### 3. Initramfs Auto-Discovery
After discovering kernel image, uefi-mkconfig will search the directory said kernel image is located in for initramfs images belonging it.

Please **do not put** the `initrd=` entry to the kernel commads in uefi-mkconfig configuration file manually. It will be stripped out of it!

If needed, initramfs image can be ignored by creating empty file named the same way with the suffix `.ignore`: 

```console
# ls -l /boot/EFI/Gentoo
total 0
-rwxr-xr-x 1 root root 0 May 29 16:26 amd-uc.img
-rwxr-xr-x 1 root root 0 May 29 16:26 initramfs-6.8.9-gentoo.img
-rwxr-xr-x 1 root root 0 May 29 16:26 initramfs-6.8.9-gentoo.img.ignore
-rwxr-xr-x 1 root root 0 May 29 16:28 vmlinuz-6.8.9-gentoo.efi
```

### 4. Microcode Loading
uefi-mkconfig can autodiscover and add microcode image to the uefi entry.
For this to happen the microcode image needs to be present in the same directory as kernel images.

If needed, microcode image can be ignored by creating empty file named the same way with the suffix `.ignore`: 

```console
# ls -l /boot/EFI/Gentoo
total 0
-rwxr-xr-x 1 root root 0 May 29 16:26 amd-uc.img
-rwxr-xr-x 1 root root 0 May 29 16:26 amd-uc.img.ignore
-rwxr-xr-x 1 root root 0 May 29 16:26 initramfs-6.8.9-gentoo.img
-rwxr-xr-x 1 root root 0 May 29 16:28 vmlinuz-6.8.9-gentoo.efi
```

### 5. SHIM Booting Compatibility
If SHIM file is present in a certain directory, all kernels residing within this directory will be configured to use it.
If multiple shim files are in the same directory, only the first one, sorted alphabetically, will be used.

For now, if SHIM booting is needed, kernel and shim have to be present within directory `/boot/EFI` or its subdirectory.

### 6. EFI Entry Labling
Each entry created by this script will have following format of entry label:

```
<UMC or UMCB> </Path/to/kernel/image/on/EFI/partition> on <partition label or UUID>
```

Normal entries are marked as `UMC` and backup entries as `UMCB`.
Entries will also be identified by patition label of a partition its kernel images is located on or in case partition label isn't set, filesystem UUID will be used.
Example:

```
Boot01FF* UMC /EFI/Gentoo/vmlinuz-6.9.9-gentoo-dist.efi on boot1
```

### 7. Ignoring Kernel Images
If needed, some kernel images can be ignored by creating an empty file in the same directory as the kernel with the same name
as efi file of the kernel image with `.ignore` suffix.
Example:

```console
# ls -la /boot/EFI/Gentoo
total 184920
drwxr-xr-x 2 root root     4096 May 10 10:47 .
drwxr-xr-x 3 root root     4096 Apr  4 10:15 ..
-rwxr-xr-x 1 root root 15703024 Apr 21 16:04 vmlinuz-6.6.21-gentoo-dist.efi
-rwxr-xr-x 1 root root        0 May 10 10:47 vmlinuz-6.6.21-gentoo-dist.efi.ignore
```

### 8. Backup Entry Creation
uefi-mkconfig can automatically create backup uefi entry at position `0100`.
This entry **will not** be automatically deleted and **will not** be added to the bootorder.
Besides these two special rules, the entry creation itself is identical to the normal processs.

**Only one kernel image** can be designated as backup. If multiple one are marked as backup, kernel of the most recent version is chosen.

To designate kernel image as backup, create an empty file in the same directory as the kernel image itsel, name it the same way but add suffix `.uefibackup`.
Example:

```console
# ls -la /boot/EFI/Gentoo/
total 236336
drwxr-xr-x 2 root root     8192 Jun 28 10:56 .
drwxr-xr-x 3 root root     4096 Apr  4 10:15 ..
-rwxr-xr-x 1 root root   274097 Jun 17 10:17 config-6.9.5-gentoo-dist
-rwxr-xr-x 1 root root   274097 Jun 24 13:57 config-6.9.6-gentoo-dist
-rwxr-xr-x 1 root root 17661133 Jun 17 10:17 initramfs-6.9.5-gentoo-dist.img
-rwxr-xr-x 1 root root 17662709 Jun 24 13:57 initramfs-6.9.6-gentoo-dist.img
-rwxr-xr-x 1 root root 17144816 Jun 17 10:17 vmlinuz-6.9.5-gentoo-dist.efi
-rwxr-xr-x 1 root root 17144816 Jun 24 13:57 vmlinuz-6.9.6-gentoo-dist.efi
-rwxr-xr-x 1 root root        0 Jun 28 10:56 vmlinuz-6.9.6-gentoo-dist.efi.uefibackup
```

## Troubleshooting

### 1. chroot problems
Sometimes when running uefi-mkconfig from within a chroot, `lsblk` can cause problems resulting in uefi-mkconfig to not work.
(For example when installing Gentoo Linux.)
If this happens, exit the chroot, copy configuration from rootfs of the system being installed to the mount point of the LiveCD and run uefi-mkconfig again outside of the chroot.
Be sure to have the EFI partition mounted.

## Credits
* [@AndrewAmmerlaan](https://github.com/AndrewAmmerlaan) for very helpful feedback.
* [Excello](https://www.excello.cz/en/) for letting me contribute during working hours.
