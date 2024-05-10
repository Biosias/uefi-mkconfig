# uefi-mkconfig
grub-mkconfig inspired script for automatically managing uefi entries for booting linux kernel directly without bootloader.

## Support

1. Adding UEFI entries for EFI-stub kernels
2. Adding UEFI entries for UKI kernels
3. Adding UEFI entries for UKI kernel via SHIM
4. Initramfs auto-discovery
5. Kernel auto-discovery

## Kernel auto-discovery

Script will detect all mounted EFI partitions, scan through them and ADD/DELETE entries depending on what was and was not found.

If you have multiple EFI partitions, please make sure all of them are mounted. If they are not, you **WILL LOSE** all auto-generated entries
for EFI files on said unmounted partition.

Recommended way to do this would be to add them all to `/etc/fstab` to be mounted on boot. 

## Initramfs auto-discovery

For initramfs to be discovered, it needs to reside in the same directory as its corresponding kernel.
Please don't insert `initrd=` into kernel commands manually. It will be discarded!

## SHIM compatibility

If shim file is present in a certain directory, all kernels residing within this directory will be configured to use it.
If multiple shim files are in the same directory, only the first one, sorted alphabetically,will be used.

For now, if SHIM booting is needed, kernel and shim have to be present within directory /boot/EFI or its subdirectory.

## Custom/Managed entries

Script will create and delete **ONLY** EFI entries with hex ID larger or equal to 0100 and less or equal to 0200.
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

When kernel commands configuration file is modified, uefi-mkconfig **will regenerate all its managed entries**.

## Entry labeling

Each entry will be labeled with kernel version + to make it easier to differentiate entries 
on different partitions from each other, PARTLABEL will be appended to the EFI entry label.

Example:

```
Boot0104* 6.8.5-gentoo-r1-nvme0n1p1
```

## Ignoring chosen kernels

If needed, some kernels can be set to be ignored by the uefi-mkconfig by creating an empty file in the same directory as the kernel with the same name
as efi file of the kernel but just with `.ignore` suffix.

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

## Credits
Special thanks to:

@AndrewAmmerlaan for very helpful feedback

[Excello](https://www.excello.cz/en/) for letting me contribute during working hours
