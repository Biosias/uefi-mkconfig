#!/bin/bash

clean-test (){
	rm -rf /boot1/EFI/Gentoo/*
	rm -rf /boot2/EFI/Gentoo/*
	rm -rf /boot3/EFI/Gentoo/*
	rm -rf /boot1/EFI/shimtest/*
	rm -rf /boot2/EFI/shimtest/*
	rm -rf /boot/efi
	rm -rf /etc/default/*

	export -n UMC_TEST
	export -n UMC_TEST_LSBLK
	export -n UMC_TEST_EFIBOOTMGR
}

simulate-run (){

	output="/out"

	[[ -f "${output}" ]] && rm "${output}"

	/bin/bash /uefi-mkconfig ${1} ${2} ${3} &>> "${output}"

	if [[ "$(sha256sum "${output}" | cut -d" " -f1)" == "$(sha256sum $expected_output_file | cut -d" " -f1)" ]]; then
		echo "Passed"
	else
		echo "Fail"
		#cat "${output}" | grep -v "TEST:"
		#diff -c "${ouput}" "$expected_output_file"
	fi
	
	echo "----"

}

mock-efi-files (){
	# Simulate same kernel versions on 2 efi partitions with corresponding initramfs image
	touch /boot1/EFI/Gentoo/vmlinuz-6.11.7-gentoo-dist.efi
	touch /boot1/EFI/Gentoo/initramfs-6.11.7-gentoo-dist.img
	
	touch /boot2/EFI/Gentoo/vmlinuz-6.11.7-gentoo-dist.efi
	touch /boot2/EFI/Gentoo/initramfs-6.11.7-gentoo-dist.img

	# Simulate microcode loading
	touch /boot3/EFI/Gentoo/vmlinuz-6.11.7-gentoo-dist.efi
	touch /boot3/EFI/Gentoo/initramfs-6.11.7-gentoo-dist.img	
	touch /boot3/EFI/Gentoo/amd-uc.img	

	# Simulate same kernel versions on 2 efi partitions without corresponding initramfs image
	touch /boot1/EFI/Gentoo/vmlinuz-6.9.7-gentoo-dist.efi

	touch /boot2/EFI/Gentoo/vmlinuz-6.9.7-gentoo-dist.efi

	# Testing entry creation for shim entries
	touch /boot1/EFI/shimtest/vmlinuz-6.11.7-gentoo-dist.efi
	touch /boot1/EFI/shimtest/shimx64.efi
	touch /boot1/EFI/shimtest/initramfs-6.11.7-gentoo-dist.img

	touch /boot2/EFI/shimtest/vmlinuz-6.11.7-gentoo-dist.efi
	touch /boot2/EFI/shimtest/shimx64.efi
	
	# Testing -old kernels
	touch /boot1/EFI/Gentoo/vmlinuz-6.11.7-gentoo-dist-old.efi
	
	touch /boot2/EFI/Gentoo/vmlinuz-6.11.2-gentoo-dist-old.efi
	touch /boot2/EFI/Gentoo/initramfs-6.11.2-gentoo-dist-old.img
}

test-first-run (){
	# Test running uefi-mkconfig without config file
	echo "Testing first run:"	

	expected_output_file="/tests/expected-out/test-first-run.expected"

	export UMC_TEST="true"
	export UMC_MOCK="true"
	export UMC_TEST_LSBLK="/tests/mock-inputs/lsblk-2-efi-partitions"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	mock-efi-files

	simulate-run
	cat "${output}"

	clean-test

	echo ""
	echo ""
}

test-missing-root (){
	echo "Testing missing root uefi-mkconfig run:"	

	expected_output_file="/tests/expected-out/test-standard-run.expected"

	export UMC_TEST="true"
	export UMC_MOCK="true"
	export UMC_TEST_LSBLK="/tests/mock-inputs/lsblk-2-efi-partitions"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	mock-efi-files

	# Insert line to configuration file for alternative entry
	echo 'KERNEL_CONFIG="%entry_id %linux_name Linux %kernel_version ; "' >> /etc/default/uefi-mkconfig

	simulate-run
	cat "${output}"

	clean-test

	echo ""
	echo ""
}

test-first-run-config-generation (){
	# Test running uefi-mkconfig without config file making sure it is generated
	echo "Testing generation of new config file upon first run:"	

	expected_output_file="/tests/expected-out/test-first-run.expected"

	export UMC_TEST="true"
	export UMC_MOCK="true"
	export UMC_TEST_LSBLK="/tests/mock-inputs/lsblk-2-efi-partitions"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	mock-efi-files

	simulate-run
	
	[[ -f /etc/default/uefi-mkconfig ]] && echo "Configuration has been created!"

	simulate-run
	cat "${output}"

	clean-test

	echo ""
	echo ""
}

test-dry-run-config-generation (){
	# Test running uefi-mkconfig without config file making sure it is generated
	echo "Testing generation of new config file upon dry run:"	

	expected_output_file="/tests/expected-out/test-first-run.expected"

	export UMC_TEST="true"
	export UMC_MOCK="false"
	export UMC_TEST_LSBLK="/tests/mock-inputs/lsblk-2-efi-partitions"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	mock-efi-files

	simulate-run
	
	if [[ -f /etc/default/uefi-mkconfig ]]; then
		echo "Configuration has been created!"
	else
		echo "Configuration does not exist!"
	fi
	cat "${output}"

	clean-test

	echo ""
	echo ""
}

test-standard-run (){
	echo "Testing standard uefi-mkconfig run:"	

	expected_output_file="/tests/expected-out/test-standard-run.expected"

	export UMC_TEST="true"
	export UMC_MOCK="true"
	export UMC_TEST_LSBLK="/tests/mock-inputs/lsblk-3-efi-partitions"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	mock-efi-files

	# Insert line to configuration file for alternative entry
	echo 'KERNEL_CONFIG="%entry_id %linux_name Linux %kernel_version ; root=/dev/sda1 "' >> /etc/default/uefi-mkconfig

	simulate-run --debug
	cat "${output}"

	clean-test

	echo ""
	echo ""
}

test-legacy-config-run (){
	echo "Testing running uefi-mkconfig with legacy config format:"	

	expected_output_file="/tests/expected-out/test-legacy-config-run.expected"

	export UMC_TEST="true"
	export UMC_MOCK="true"
	export UMC_TEST_LSBLK="/tests/mock-inputs/lsblk-2-efi-partitions"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	mock-efi-files

	# Insert line to configuration file for alternative entry
	echo 'root=/dev/sda1 test=test' >> /etc/default/uefi-mkconfig

	simulate-run
	cat "${output}"

	clean-test

	echo ""
	echo ""
}

test-latest-only-run (){
	echo "Testing latest-only uefi-mkconfig run:"	

	expected_output_file="/tests/expected-out/test-latest-only-run.expected"

	export UMC_TEST="true"
	export UMC_MOCK="true"
	export UMC_TEST_LSBLK="/tests/mock-inputs/lsblk-2-efi-partitions"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	mock-efi-files

	# Insert line to configuration file for alternative entry
	echo 'KERNEL_CONFIG="%entry_id %linux_name Linux %kernel_version ; root=/dev/sda1"' >> /etc/default/uefi-mkconfig

	# Turn on Latest Only in the config
	echo "ONLY_LATEST=true" >> /etc/default/uefi-mkconfig

	simulate-run
	cat "${output}"

	clean-test

	echo ""
	echo ""
}

test-forwardslashes (){
	echo "Testing forwardslashes uefi-mkconfig run:"	

	expected_output_file="/tests/expected-out/test-latest-only-run.expected"

	export UMC_TEST="true"
	export UMC_MOCK="true"
	export UMC_TEST_LSBLK="/tests/mock-inputs/lsblk-2-efi-partitions"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	mock-efi-files

	# Insert line to configuration file for alternative entry
	echo 'KERNEL_CONFIG="%entry_id %linux_name Linux %kernel_version ; root=/dev/sda1"' >> /etc/default/uefi-mkconfig

	# Turn on Latest Only in the config
	echo "EFI_LOADER_FORWARDSLASH=true" >> /etc/default/uefi-mkconfig

	simulate-run
	cat "${output}"

	clean-test

	echo ""
	echo ""
}

test-boot-efi-mountpoint (){
	echo "Testing boot-efi-mountpoint test uefi-mkconfig run:"	

	# Created because of issue #39

	expected_output_file="/tests/expected-out/test-latest-only-run.expected"

	export UMC_TEST="true"
	export UMC_MOCK="true"
	export UMC_TEST_LSBLK="/lsblktest"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	echo "nvme0n1p1                                  /boot/efi           c12a7328-f81f-11d2-ba4b-00a0c93ec93b  1 44EA-57CC   linux-boot" > "/lsblktest"

	mkdir -p "/boot/efi/EFI/Gentoo/"
	touch "/boot/efi/EFI/Gentoo/vmlinuz-6.12.58-gentoo-dist-old.efi"

	# Insert line to configuration file for alternative entry
	echo 'KERNEL_CONFIG="%entry_id %linux_name Linux %kernel_version ; root=/dev/nvme1p1"' >> /etc/default/uefi-mkconfig

	simulate-run
	cat "${output}"

	clean-test

	echo ""
	echo ""
}

test-backup-entries-run (){
	echo "Testing backups entries run:"	

	expected_output_file="/tests/expected-out/test-standard-run.expected"

	export UMC_TEST="true"
	export UMC_MOCK="true"
	export UMC_TEST_LSBLK="/tests/mock-inputs/lsblk-2-efi-partitions"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	mock-efi-files
	
	touch /boot1/EFI/Gentoo/vmlinuz-6.11.7-gentoo-dist.efi.uefibackup

	# Insert line to configuration file for alternative entry
	echo 'KERNEL_CONFIG="%entry_id %linux_name Linux %kernel_version ; root=/dev/sda1 "' >> /etc/default/uefi-mkconfig

	simulate-run
	cat "${output}"

	clean-test

	echo ""
	echo ""
}

test-verbose-and-debug-run (){
	echo "Testing verbose and debug uefi-mkconfig run:"	

	expected_output_file="/tests/expected-out/test-standard-run.expected"

	export UMC_TEST="true"
	export UMC_MOCK="true"
	export UMC_TEST_LSBLK="/tests/mock-inputs/lsblk-2-efi-partitions"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	mock-efi-files

	# Insert line to configuration file for alternative entry
	echo 'KERNEL_CONFIG="%entry_id %linux_name Linux %kernel_version ; root=/dev/sda1 "' >> /etc/default/uefi-mkconfig

	simulate-run -v --debug
	cat "${output}"

	clean-test

	echo ""
	echo ""
}

run_tests() {

	test-first-run

	test-first-run-config-generation

	test-missing-root

	test-standard-run

	test-legacy-config-run

	test-latest-only-run

	test-forwardslashes

	test-boot-efi-mountpoint

	test-dry-run-config-generation

	test-backup-entries-run

	test-verbose-and-debug-run
}

if [[ -f /inside-umc-test-chroot ]]; then

	output_log="/log/out"
	
	run_tests &> "${output_log}"

	cat "${output_log}"

else
	echo "Not in test chroot, stopping. Run run_chroot_tests.sh to tun these tests in safe chroot!"
fi
