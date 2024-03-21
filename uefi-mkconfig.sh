#!/usr/bin/env bash
#NEEDED:
## Shim booting

check_if_uefi_entry_exists () {
	for entry in $(efibootmgr); do
		
		# Added last case because while testing this script I found that sometimes, firmware uppercases the path and reverts backslash to forward slash
		if [[ "$entry" == *"$partition_partuuid"* ]]; then
			if [[ "$entry" == *"(${efi_file_path//\//\\}"* ]]; then
	
				return 0

			elif [[ "$entry" == *"(${efi_file_path^^}"* ]]; then

				return 0

			fi
		fi
			
	done
	return 1
}

add_uefi_entries () (
	for efi_file in $partition_efis; do
		
		# Prepare path which will be inserted into efibootmgr
		local efi_file_path=$(echo "${efi_file//$partition_mount}")

		# Add entry if it doesn't exist
		if ! check_if_uefi_entry_exists; then
		
			local bootnum=256 # 256 is decimal value of 0100
			local efibootmgr="$(efibootmgr)"

			# Find first free hex address larger than or equal to 0100 for new UEFI boot entry
			while [ "$(echo ${efibootmgr/*Boot$(printf %04X $bootnum)*/})" == "" ]; do

				local bootnum=$(($bootnum + 1))

			done
			
			# Get kernel version
			## Remove everything before /
			local kernel_version="${efi_file_path//*\//}"
			## Remove everything before first - to remove any prefixes
			local kernel_version="${kernel_version/${kernel_version%%-*}-/}"
			## Remove .efi suffix if it exists
			if [[ "$kernel_version" == *".efi"* ]]; then
				local kernel_version="${kernel_version/\.${kernel_version##*.}}"
			fi

			# Create label for UEFI entry
			if [[ -n ${partition_label} ]]; then
				local entry_label="$kernel_version-$(lsblk "/dev/$partition" -lno PARTLABEL)"
			else
				local entry_label="$kernel_version"
			fi

			# Check if corresponding initramfs exists	
			local initramfs_image="${efi_file_path/${efi_file_path##*/}}initramfs-$kernel_version.img"
			if [[ -f "$partition_mount$initramfs_image" ]]; then
				kernel_commands="${kernel_commands} initrd=${initramfs_image//\//\\}"
			fi

			# Add new entry
			echo "Adding UEFI entry for $efi_file_path found on $partition..."
			efibootmgr --create -b $(printf %04X $bootnum) --disk /dev/$partition --label "$entry_label" --loader "${efi_file_path//\//\\}" -u "$kernel_commands" &>/dev/null || (echo "!!! Failed to add UEFI entry for $efi_file_path !!!"; exit i1)
			
		else
		
			echo "UEFI Entry already exists for $efi_file_path on $partition !"	
		
		fi
	done
)

remove_uefi_entries () {

	IFS=$'\n'		
	for entry in $(efibootmgr | grep $partition_partuuid); do

		#Create path to efi file
		#Not the nicest way to do it but for now its ok
		local entry_efi_path=$(echo $entry | sed 's/.*File(//g' | sed 's/.efi.*/.efi/g' | sed 's/\\/\//g')
			
		local uefi_entry_hex="$(echo $entry | cut -d' ' -f1 | sed 's/\*.*//g' | sed 's/Boot//g')"
			
		# Check if efi file exists and if this entry in in managed range
		if [ ! -f "$partition_mount$entry_efi_path" ] && [[ $(echo $((16#$uefi_entry_hex))) > 255 ]]; then
				
			# Delete entry
			echo "!!! EFI file $entry_efi_path on $partition doesn't exist. Deleting its entry $uefi_entry_hex !!!"
			efibootmgr -q -B -b $uefi_entry_hex || (echo "!!! Failed to delete entry $uefi_entry_hex !!!"; exit 1)

		fi

	done

}

main () {
	efi_parttype="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
	mounted_efi_partitions=$(lsblk -lo NAME,MOUNTPOINTS,PARTTYPE | grep  "$efi_parttype" | grep "/" | cut -d' ' -f1)

	# Load kernel commands from config files
	if [[ -n "${INSTALLKERNEL_CONF_ROOT}" ]]; then
		if [[ -f "${INSTALLKERNEL_CONF_ROOT}/cmdline" ]]; then
			kernel_commands="$(tr -s "${IFS}" ' ' <"${KERNEL_INSTALL_CONF_ROOT}/cmdline")"
		fi
	elif [[ -f /etc/kernel/cmdline ]]; then
		kernel_commands="$(tr -s "${IFS}" ' ' </etc/kernel/cmdline)"
	elif [[ -f /usr/lib/kernel/cmdline ]]; then
		kernel_commands="$(tr -s "${IFS}" ' ' </usr/lib/kernel/cmdline)"
	else
		kernel_commands="$(tr -s "${IFS}" '\n' </proc/cmdline | grep -ve '^BOOT_IMAGE=' -e '^initrd=' | tr '\n' ' ')"
	fi

	for partition in $mounted_efi_partitions; do
		
		# Find partition uuid
		partition_partuuid=$(lsblk "/dev/$partition" -lno PARTUUID)

		# Find where disk is mounted
		# Head at the end deals with cases where this partition is mounted in multiple places
		partition_mount=$(lsblk "/dev/$partition" -lno MOUNTPOINTS | head -n 1)

		# Find all .efi files on this partition
		partition_efis="$(find $partition_mount \( -name "vmlinuz-*.efi" -o -name "vmlinux-*.efi" -o -name "gentoo-*.efi" -o -name "kernel-*.efi" -o -name "bzImage*.efi" -o -name "zImage*.efi" -o -name "vmlinuz.efi" \))"
		
		# Remove entries for efi files that no longer exist
		remove_uefi_entries	

		# Add missiong efi entries for efi files that exist
		add_uefi_entries	
	done

}

main
