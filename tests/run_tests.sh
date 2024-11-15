#!/bin/bash

clean-test (){
	rm -rf /boot1/EFI/Gentoo/*
	rm -rf /boot2/EFI/Gentoo/*
	rm -rf /boot1/EFI/shimtest/*
	rm -rf /boot2/EFI/shimtest/*
	rm -rf /etc/default/*

	export -n UMC_TEST
	export -n UMC_TEST_LSBLK
	export -n UMC_TEST_EFIBOOTMGR
}

simulate-run (){

	[[ -f /out ]] && rm /out

	/bin/bash /uefi-mkconfig &> /out

	if [[ "$(sha256sum /out | cut -d" " -f1)" == "$(sha256sum $expected_output_file | cut -d" " -f1)" ]]; then
		echo "Passed"
	else
		echo "Fail"
		diff -c "/out" "$expected_output_file"
	fi
	
	echo "----"

}

mock-efi-files (){
	# Simulate same kernel versions on 2 efi partitions with corresponding initramfs image
	touch /boot1/EFI/Gentoo/vmlinuz-6.11.7-gentoo-dist.efi
	touch /boot1/EFI/Gentoo/initramfs-6.11.7-gentoo-dist.img
	
	touch /boot2/EFI/Gentoo/vmlinuz-6.11.7-gentoo-dist.efi
	touch /boot2/EFI/Gentoo/initramfs-6.11.7-gentoo-dist.img

	# Simulate same kernel versions on 2 efi partitions without corresponding initramfs image
	touch /boot1/EFI/Gentoo/vmlinuz-6.9.7-gentoo-dist.efi

	touch /boot2/EFI/Gentoo/vmlinuz-6.9.7-gentoo-dist.efi

	# Testing entry creation for shim entries
	touch /boot1/EFI/shimtest/vmlinuz-6.11.7-gentoo-dist.efi
	touch /boot1/EFI/shimtest/shimx64.efi
	touch /boot1/EFI/shimtest/initramfs-6.11.7-gentoo-dist.img

	touch /boot2/EFI/shimtest/vmlinuz-6.11.7-gentoo-dist.efi
	touch /boot2/EFI/shimtest/shimx64.efi
}

test-first-run (){
	# Test running uefi-mkconfig without config file
	echo "Testing first run:"	

	expected_output_file="/tests/expected-out/test-first-run.expected"

	export UMC_TEST="true"
	export UMC_TEST_LSBLK="/tests/mock-inputs/lsblk-2-efi-partitions"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	mock-efi-files

	simulate-run

	clean-test
}

test-standard-run (){
	echo "Testing standard uefi-mkconfig run:"	

	expected_output_file="/tests/expected-out/test-standard-run.expected"

	export UMC_TEST="true"
	export UMC_TEST_LSBLK="/tests/mock-inputs/lsblk-2-efi-partitions"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	mock-efi-files

	# Run it once before test run to generate default uefi-mkconfig configuration file
	/bin/bash /uefi-mkconfig &> /dev/null

	# Insert line to configuration file for alternative entry
	echo 'KERNEL_CONFIG="%entry_id %linux_name Linux 2 %kernel_version ; "' >> /etc/default/uefi-mkconfig

	simulate-run

	clean-test
}

test-legacy-config-run (){
	echo "Testing running uefi-mkconfig with legacy config format:"	

	expected_output_file="/tests/expected-out/test-legacy-config-run.expected"

	export UMC_TEST="true"
	export UMC_TEST_LSBLK="/tests/mock-inputs/lsblk-2-efi-partitions"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	mock-efi-files

	# Insert line to configuration file for alternative entry
	echo 'root=/dev/sda1 test=test"' >> /etc/default/uefi-mkconfig

	simulate-run

	clean-test
}

if [[ -f /inside-umc-test-chroot ]]; then

	test-first-run

	test-standard-run

	test-legacy-config-run

else
	echo "Not in test chroot, stopping"
fi
