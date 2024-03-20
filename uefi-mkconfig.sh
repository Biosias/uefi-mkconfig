#!/usr/bin/env bash
# NEEDED:
## Add initramfs discovery
## 

check_if_uefi_entry_exists () {
	for entry in $(efibootmgr); do

		if [[ "$entry" == *"($efi_path"* ]] && [[ "$entry" == *"$partition_uuid"* ]]; then
			
			return 0
		fi
			
	done
	return 1
}

add_uefi_entry () (
	for efi in $partition_efis; do
		
		# Prepare path which will be inserted into efibootmgr
		local efi_path=$(echo "${efi//$partition_mount}" | sed 's/\//\\/g')

		# Add entry if it doesn't exist
		if ! check_if_uefi_entry_exists; then
		
			local bootnum=256 # 256 is decimal value of 0100
			local efibootmgr="$(efibootmgr)"

			# Find first free hex address larger than or equal to 0100 for new UEFI boot entry
			while [ "$(echo ${efibootmgr/*Boot$(printf %04X $bootnum)*/})" == "" ]; do

				local bootnum=$(($bootnum + 1))

			done
			
			# Get partition LABEL
			local partition_label="$(lsblk "/dev/$partition" -lno LABEL)"

			# Create label for UEFI entry
			if [[ -n ${partition_label} ]]; then
				local entry_label="$(echo $efi_path | sed "s/.*vmlinuz-//g" | sed "s/.*kernel-//g" | sed "s/\.efi//g")-$partition_label"
			else
				local entry_label="$(echo $efi_path | sed "s/.*vmlinuz-//g" | sed "s/.*kernel-//g" | sed "s/\.efi//g")"
			fi

			# Try autodiscover iniramfs images	
			local kernel_version="$( echo ${efi_path//*\\/} | sed "s/.efi//" | sed "s/-plain.*//" | sed "s/kernel-//" | sed "s/vmlinuz-//" | sed "s/vmlinux-//" | sed "s/-plain*//")"
			local initramfs_image="$(echo ${efi_path//\\/\/} | sed "s/${efi_path//*\\/}//")initramfs-$kernel_version.img"
			if [[ -f "$partition_mount$initramfs_image" ]]; then

				kernel_commands="${kernel_commands} initrd=${initramfs_image//\//\\}"

			fi

			# Add entry
			echo "Adding UEFI entry for $efi_path found on $partition..."
			efibootmgr --create -b $(printf %04X $bootnum) --disk /dev/$partition --label "$entry_label" --loader "$efi_path" -u "$kernel_commands" &>/dev/null || (echo "!!! Failed to add UEFI entry for $efi_path !!!"; exit i1)
			
		else
		
			echo "UEFI Entry already exists for $efi_path on $partition !"	
		
		fi
	done
)

main () {
	efi_parttype="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
	mounted_esp=$(lsblk -lo NAME,MOUNTPOINTS,PARTTYPE | grep  "$efi_parttype" | grep "/" | cut -d' ' -f1)

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

	for partition in $mounted_esp; do
		
		# Find partition uuid
		partition_partuuid=$(lsblk "/dev/$partition" -lno PARTUUID)

		# Find where disk is mounted
		# Head at the end deals with cases where this partition is mounted in multiple places
		partition_mount=$(lsblk "/dev/$partition" -lno MOUNTPOINTS | head -n 1)

		# Find all .efi files on this partition
		partition_efis="$(find $partition_mount \( -name "vmlinuz-*" -o -name "vmlinux-*" -o -name "gentoo-*.efi" -o -name "kernel-*" -o -name "bzImage*" \))"
		
		# ---- Remove invalid entries ----
		IFS=$'\n'		
		for entry in $(efibootmgr | grep $partition_partuuid); do

			#Create path to efi file
			#Not the nicest way to do it but for now its ok
			local efi_path=$partition_mount$(echo $entry | sed 's/.*File(//g' | sed 's/.efi.*/.efi/g' | sed 's/\\/\//g')
			
			uefi_entry_hex="$(echo $entry | cut -d' ' -f1 | sed 's/\*.*//g' | sed 's/Boot//g')"
			
			# Check if efi file exists and if this entry in in managed range
			if [ ! -f "$efi_path" ] && [[ $(echo $((16#$uefi_entry_hex))) > 255 ]]; then
				
				# Delete entry
				echo "!!! EFI file $efi_path on $partition doesn't exist. Deleting its entry $uefi_entry_hex !!!"
				efibootmgr -q -B -b $uefi_entry_hex || (echo "!!! Failed to delete entry $uefi_entry_hex !!!"; exit 1)

			fi

		done
		# ----
		

		add_uefi_entry	
	done

}

main
