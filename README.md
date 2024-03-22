# uefi-mkconfig
grub-mkconfig inspired script for automatically managing uefi entries for booting linux kernel directly without bootloader

## Features

1. EFI-stub kernels
2. UKI kernels
3. UKI kernel via SHIM
4. Initramfs autodiscovery
5. Kernel autodiscovery

## Kernel autodetection

Script will detect all mounted EFI partitions, scan through them and ADD/DELETE entries depending on what was and was not found.
Layout of the EFI partition doesn't matter. Only constraints are that kernel and its corresponding initramfs need to reside in the same directory
So if you don't want to loose UEFI entries, make sure all EFI partitions are mounted and accessible.
Best to just add all EFI partitions to fstab to be auto-mounted on boot.

## SHIM compatibility

If shim file is present in a certain directory, all kernels residing within this directory will be configure to use it.
If multiple shim files are in the same directory, only the first one will be used when sorted alphabetically.

## Custom/Managed entries

Script will create and delete ONLY EFI entries with hex ID larger or equal to 0100.
If custom entry is needed, assign it hex ID below this value.

## Kernel Commands

For configuring kernel commands following config options can be used:
```
/etc/kernel/cmdline
/usr/lib/kernel/cmdline
```

if none of these exist, commands will be taken from /proc/cmdline.

Script WILL NOT regenerate entries after kernel commands config has been modified. If this is needed, please manually delete those entries that need to be regenerated.

POSSIBLE FUTURE FEATURE: Regenerate all entries.

## Entry labeling

Each entry will be labeled with kernel version.
To make it easier to differentiate entires on different partitions from each other, PARTLABEL will be appended to the EFI entry label.
