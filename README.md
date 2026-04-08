# uefi-mkconfig
grub-mkconfig inspired script for automatically managing UEFI boot entries.

## Goal
Make use of UEFIs direct kernel boot feature as simple as possible so it can be used as an alternative to bootloaders. 

## Warning!
Implementation of UEFI Firmware functions like setting boot order and creation of boot entries is very inconsistent across motherboard vendors.

These inconsistencies result in erratic behaviour which may cause unpredictable behaviour when using uefi-mkconfig on certain motherboards.

**Therefore we strongly recommend testing uefi-mkconfig on a new system before using it in production.**

Some of these problems can be mitigated by us in the uefi-mkconfig code so if you encouter any weird behaviour, please don't hesitate to open an Issue.

## Setup
After installation there are few steps that need to be taken before uefi-mkconfig can be used:

### 1. Install the dependencies (if installed outside of package manager)
uefi-mkconfig uses the following programs:
* Bash,
* efibootmgr,
* GNU Core Utilities,
* util-linux,
* GNU Find Utilities.

### 2. Verify boot partition type
uefi-mkconfig uses the `lsblk` command to identify which mounted partitions are EFI partitions.

Because of this, all EFI partitions need to be of a correct partition type.

```
PARTTYPE: c12a7328-f81f-11d2-ba4b-00a0c93ec93b
PARTTYPENAME: EFI System
```

Following is an example of how to verify this:

```console
# lsblk -o +PARTTYPE,PARTTYPENAME
NAME                                          MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINTS
                                                                                PARTTYPE                             PARTTYPENAME
nvme0n1                                       259:0    0 500G  0 disk
├─nvme0n1p1                                   259:1    0     1G  0 part  /boot  c12a7328-f81f-11d2-ba4b-00a0c93ec93b EFI System
```

### 3. Verify kernel installation
Each kernel image file needs to end in `.efi` because some UEFI Firmware implementation will refuse to boot it otherwise.

### 4. Configuration
uefi-mkconfig will look for its configuration file in following directories (in this order)

* `/etc/default/uefi-mkconfig`
* `/etc/kernel/uefi-mkconfig`
* `/usr/lib/kernel/uefi-mkconfig`

If configuration file isn't found, running uefi-mkconfig will generate skeleton config file in `/etc/default/`.

In said file, you can configure kernel commandline arguments, templates for naming UEFI boot entries and other available options.

Following are examples of a configured label template with its corresponding kernel commandline arguments:

```bash
KERNEL_CONFIG="%entry_id %linux_name Linux %kernel_version ; root=/dev/mapper/gentoo-root rootfstype=ext4 resume=/dev/mapper/gentoo-swap"
```

You can create multiple lines like this with different label template and kernel commandline arguments so uefi-mkconfig will create multiple different entries for each kernel image file.
**Order of these lines in the configuration file is important since it will be the order in which the entries are added.**

### 5. Add all EFI partitions to fstab
uefi-mkconfig autodiscovers kernel image files by searching through the filesystems of all mounted EFI partitions.
This means that having all EFI partitions you want to use, mounted upon running uefi-mkconfig is paramount.
If only some of them are mounted, **you will loose** entries for kernel image files located on partitions which are not.
If there are no mounted EFI partitions, uefi-mkconfig will refuse to run.

Because of this, adding all EFI partitions, you want to use, into the `/etc/fstab` file is **strongly** recommended.

## Running uefi-mkconfig

```
Usage: uefi_mkconfig [options]
        --help -h       Print this help message and exit
        --version -V    Print version only and exit
        --verbose -v    Run in verbose mode
        --debug         Run in debug mode
        --dry-run -d    Run in dry-run mode without writing any changes to the UEFI Firmware"
```

## Features

### 1. Automatic UEFI Entry Management
uefi-mkconfig uses `efibootmgr` to create and delete EFI entries.

Automatic management is limited to range `0100`-`0200` Boot IDs in the UEFI Firmware.
These IDs are hexadecimal numbers, so there are 256 slots which are managed automatically.

If you need to add custom entry please add it outside of this range.
This will ensure that uefi-mkconfig will not touch your manually added entry.

`ONLY_LATEST=true` can be set in the configuration file to force uefi-mkconfig to only add entry of the most recent kernel version available.

### 2. Kernel Auto-Discovery
uefi-mkconfig searches through filesystem of each mounted EFI partitions and creates EFI entries for each kernel image file (`.efi` files) it finds.

### 3. Initramfs Auto-Discovery
After discovering kernel image file, uefi-mkconfig will search the directory of said kernel image file for initramfs image file belonging it.

**Please do not add the `initrd=` entry to the kernel commads in uefi-mkconfig configuration file manually. It will be stripped out of it!**

If needed, initramfs image file can be ignored by creating empty file named the same way with the suffix `.ignore`: 

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
For this to happen the microcode image file needs to be present in the same directory as kernel image file.

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

**For now, if SHIM booting is needed, kernel and shim have to be present within directory `/boot/EFI` or its subdirectory.**

### 6. EFI Entry Labling
Entry label template is defined in the configuration file in the first section of the `KERNEL_CONFIG` line before the ` ; ` separator

By default it has limit of 56 characters for regular entries and 55 for backup entries to increase compatibility with as many systems as possible.
This limit can be overridden with setting `ENTRY_LABEL_LIMIT=true` to false.
Testing is recommended before using entry labels longer than the set limit before using it in production.

Following is a list of variables which could be used in entry label templates:

1. `%efi_file_path` - Path to the efi file of the kernel
2. `%partition_label` - Partition label of a partition on which the kernel image being added resides
3. `%kernel_release` - Version of a kernel being added including localconfig suffix
4. `%kernel_version` - Version of a kernel being added
5. `%linux_name` - Distribution name of the syste
6. `%entry_id` - ID of the entry being added (Recommended to avoid accidentally adding multiple entries with the same label)
7. `%partition` - Partition on which the kernel image being added resides

### 7. Ignoring Kernel Images
If needed, kernel image files can be ignored by creating an empty file in the same directory with `.ignore` suffix.

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
If this happens, make sure that `/run` is mounted correctly into the chroot.
If the problem persits even after mounting `/run`, exit the chroot, copy configuration from rootfs of the system being installed to the mount point of the LiveCD and run uefi-mkconfig again outside of the chroot.
Be sure to have the EFI partition mounted.

### 2. UEFI Firmware boots entry in descending order of entry IDs
Some UEFI Firmawere were shown to behave like this. uefi-mkconfig by default adds the newest kernel last since default behaviour of efibootmgr is to set last added option as next to boot.
This approach will not work if this problem exists so option "REVERS_ORDER" was added as a option to the config file. If set to true, uefi-mkconfig will add newest kernels first.
This should mitigate this issue.

## Credits
* [@Nowa-Ammerlaan](https://github.com/Nowa-Ammerlaan) for very helpful feedback.
* [Excello](https://www.excello.cz/en/) for letting me contribute during working hours.
* [@kuraga](https://github.com/kuraga) for very helpful feedback.
