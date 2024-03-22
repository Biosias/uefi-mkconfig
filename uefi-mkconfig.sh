#!/usr/bin/env bash

check_if_uefi_entry_exists () {
	for entry in $(efibootmgr -u); do
		# Added last case because while testing this script I found that sometimes, firmware uppercases the path and reverts backslash to forward slash
		if [[ "$entry" == *"$partition_partuuid"* ]]; then
			if [[ "$entry" == *"(${efi_file_path//\//\\}"* ]] || [[ "$entry" == *"(${efi_file_path^^}"* ]]; then
	
				return 0

			# Added for handling shim entries
			elif [[ "$entry" ==  *")${efi_file_path//\//\\}"* ]] || [[ "$entry" ==  *")${efi_file_path^^}"* ]]; then
		
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

		local adding_kernel_commands="${kernel_commands}"

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
			local partition_label="$(lsblk "/dev/$partition" -lno PARTLABEL)"
			if [[ -n ${partition_label} ]]; then
				local entry_label="$kernel_version-$partition_label"
			else
				local entry_label="$kernel_version"
			fi

			# Check if corresponding initramfs exists
			local initramfs_image="${efi_file_path/${efi_file_path##*/}}initramfs-$kernel_version.img"
			if [[ -f "$partition_mount$initramfs_image" ]]; then
				local adding_kernel_commands="${adding_kernel_commands} initrd=${initramfs_image//\//\\}"
			else
				echo "!!! WARNING: No initramfs found for $efi_file_path !!!"
			fi

			# If shim is present in directory, presume it's used for every kernel in said directory
			local shim="$(find $partition_mount${efi_file_path/${efi_file_path##*/}/} -maxdepth 1 -iname "*shim*.efi")"
			if [[ "$shim" != "" ]]; then
				local shim="${shim%%.efi*}.efi"
				local adding_kernel_commands="${efi_file_path//\//\\} ${adding_kernel_commands}"
				echo "Adding UEFI entry for $efi_file_path using shim $shim found on $partition..."
				local efi_file_path="${efi_file_path/${efi_file_path##*/}/}${shim/*\//}"
			else
				echo "Adding UEFI entry for $efi_file_path found on $partition..."
			fi

			# Add new entry
			echo ""
			efibootmgr --create -b $(printf %04X $bootnum) --disk /dev/$partition --label "$entry_label" --loader "${efi_file_path//\//\\}" -u "$adding_kernel_commands" &>/dev/null || (echo "!!! ERROR: Failed to add UEFI entry for $efi_file_path !!!"; exit i1)
			
		else
		
			echo "UEFI Entry already exists for $efi_file_path on $partition !"
			echo ""
		
		fi
	done
)

remove_uefi_entries () {

	IFS=$'\n'		
	for entry in $(efibootmgr -u | grep $partition_partuuid); do

		#Create path to efi file
		## Decide if entry is shim entry or not
		if [[ "$entry" !=  *"File("*"shim"*")"* ]] && [[ "$entry" !=  *"File("*"SHIM"*")"* ]]; then
			### Remove everything before first mention of string File(
			local entry_efi_path="${entry/${entry%%File(*}File\(/}"
			### Remove everything after first ) character
			local entry_efi_path="${entry_efi_path%%)*}"
		else
			### Remove everything after and included with last character )
			local entry_efi_path="${entry##*)}"
			### Remove everything after and included with last space
			local entry_efi_path="${entry_efi_path%% *}"
		fi

		# Get Hex number of a entry
		## Remove everything after first space
		local uefi_entry_hex="${entry%%\ *}"
		## Remove string Boot
		local uefi_entry_hex="${uefi_entry_hex/Boot/}"
		## Remove character *
		local uefi_entry_hex="${uefi_entry_hex/\*/}"

		# Check if efi file exists and if this entry in in managed range
		if [ ! -f "$partition_mount${entry_efi_path//\\/\/}" ] && [[ $(echo $((16#$uefi_entry_hex))) > 255 ]]; then
				
			# Delete entry
			echo "!!! EFI file $entry_efi_path on $partition doesn't exist. Deleting its entry $uefi_entry_hex !!!"
			efibootmgr -q -B -b $uefi_entry_hex || (echo "!!! ERROR: Failed to delete entry $uefi_entry_hex !!!"; exit 1)

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
