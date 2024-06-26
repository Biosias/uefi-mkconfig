# uefi-mkconfig
grub-mkconfig inspired script for automatically managing uefi entries for booting linux kernel directly without a bootloader.

## Kernel auto-discovery

Uefi-mkconfig will detect all mounted EFI partitions, scan through them and ADD/DELETE entries depending on what was and was not found.

If you have multiple EFI partitions, please make sure all of them are mounted. If they are not, you **WILL LOSE** all auto-generated entries
for EFI files on said unmounted partition.

Recommended way to do this would be to add them all to `/etc/fstab` to be mounted on boot.

WARNING: Make sure when creating said EFI partition, its PARTTYPE is set to c12a7328-f81f-11d2-ba4b-00a0c93ec93b or in other words, it needs to have PARTTYPENAME=EFI System. You can verify this by running `lsblk -o +PARTTYPE,PARTTYPENAME`

## Initramfs auto-discovery

For initramfs to be discovered, it needs to reside in the same directory as its corresponding kernel.
Please don't insert `initrd=` into kernel commands manually. It will be discarded!

## Microcode loading

Uefi-mkconfig can autodiscover and add microcode image to the uefi entry.
For this to happen the microcode image needs to be present in the same directory as kernel images.

If needed, microcode image can be ignored by creating empty file named the same way with the suffix .ignore 

```
user@machine1:~:$ ls -l /boot/EFI/Gentoo
total 0
-rwxr-xr-x 1 root root 0 May 29 16:26 amd-uc.img
-rwxr-xr-x 1 root root 0 May 29 16:26 amd-uc.img.ignore
-rwxr-xr-x 1 root root 0 May 29 16:26 initramfs-6.8.9-gentoo.img
-rwxr-xr-x 1 root root 0 May 29 16:28 vmlinuz-6.8.9-gentoo.efi
```

## SHIM compatibility

If shim file is present in a certain directory, all kernels residing within this directory will be configured to use it.
If multiple shim files are in the same directory, only the first one, sorted alphabetically,will be used.

For now, if SHIM booting is needed, kernel and shim have to be present within directory /boot/EFI or its subdirectory.

## Custom/Managed entries

Script will create and delete **ONLY** EFI entries with hex ID larger or equal to 0100 and less or equal to 0200.
ID 0200 is dedicated for automatic backup entry creation. This entry will not be deleted automatically!
If custom entry is needed, assign it hex ID below or above this range.

## Kernel Commands

For configuring kernel commands following config file options can be used:

```
/etc/default/uefi-mkconfig
/etc/kernel/uefi-mkconfig
/usr/lib/kernel/uefi-mkconfig
```

if none of these exist, commands will be taken from `/proc/cmdline`.

Format of the configuration file should be **ONLY** space separated list of kernel commads.

Example:

```
machine1 ~ # cat /etc/default/uefi-mkconfig
crypt_root=UUID=dcb0cc6f-ddac-ge38-b92c-e59edc55dv61 root=/dev/mapper/gentoo rootfstype=ext4 resume=/dev/mapper/swap dolvm quiet
```

## Entry labeling

Each entry will be labeled with kernel version + to make it easier to differentiate entries 
on different partitions from each other, PARTLABEL will be appended to the EFI entry label.

Example:

```
Boot0104* 6.8.5-gentoo-r1-nvme0n1p1
```

## Ignoring certain kernel version/s

If needed, some kernel images can be ignored by creating an empty file in the same directory as the kernel with the same name
as efi file of the kernel image with `.ignore` suffix.

Example:

```
machine1 /boot/EFI/Gentoo # ls -la
total 184920
drwxr-xr-x 2 root root     4096 May 10 10:47 .
drwxr-xr-x 3 root root     4096 Apr  4 10:15 ..
-rwxr-xr-x 1 root root 15703024 Apr 21 16:04 vmlinuz-6.6.21-gentoo-dist.efi
-rwxr-xr-x 1 root root        0 May 10 10:47 vmlinuz-6.6.21-gentoo-dist.efi.ignore
```

WARNING: If uefi entry was already created by uefi-mkconfig for this kernel before `.ignore` file creation. **Its uefi entry will be deleted!**

## Backup UEFI entry creation

uefi-mkconfig can automatically create backup uefi entry at position 0100.
This entry **will not** be automatically deleted and **will not** be added to the bootorder.
Besides these two special rules, the entry creation itself is identical to the normal processs.

**Only one kernel image** can be designated as backup. If multiple one are marked as backup, kernel of the most recent version is chosen.

To designate kernel image as backup, create an empty file in the same directory as the kernel image itsel, name it the same way but add suffix ".uefibackup"

Example:
```
user@machine1:~:$ ls -la /boot/EFI/Gentoo/
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

This backup entry will be marked by UMCB string in the label entry


## Troubleshooting

Sometimes when running uefi-mkconfig from within a chroot, lsblk can cause problems resulting in uefi-mkconfig to not work. (For example when installing Gentoo linux) 
If this happens, exit the chroot, copy configuration from rootfs of the system being installed to the fs of the liveCD and run uefi-mkconfig again outside of the chroot. Be sure to have the EFI partition mounted.

## Credits
Special thanks to:

@AndrewAmmerlaan for very helpful feedback

[Excello](https://www.excello.cz/en/) for letting me contribute during working hours
