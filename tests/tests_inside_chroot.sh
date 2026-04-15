#!/usr/bin/env bash
set -euo pipefail

readonly ref_dir="${TEST_REF_DIR:-"/tests/expected-out"}"
readonly out_dir="/log"
check_output=true
num_test=0
num_fail=0

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

	local -r output="$out_dir/${FUNCNAME[1]}"
	local -r expected_output_file="${ref_dir}/${FUNCNAME[1]}.expected"
	
	set +e
	/bin/bash /uefi-mkconfig "$@" 2>&1 | tee "$output"
	echo "${PIPESTATUS[0]}"| tee -a "$output"
	set -e

	if $check_output; then
		((num_test+=1))
		if [[ "$(sha256sum "${output}" | cut -d" " -f1)" == "$(sha256sum "$expected_output_file" | cut -d" " -f1)" ]]; then
			echo "$num_test: Passed"
		else
			echo "$num_test: Fail"
			((num_fail+=1))
			#cat "${output}" | grep -v "TEST:"
			#diff -c "${ouput}" "$expected_output_file"
		fi
		
		echo "----"
	fi

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

	export UMC_TEST="true"
	export UMC_MOCK="true"
	export UMC_TEST_LSBLK="/tests/mock-inputs/lsblk-2-efi-partitions"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	mock-efi-files

	simulate-run

	clean-test

	echo ""
	echo ""
}

test-missing-root (){
	echo "Testing missing root uefi-mkconfig run:"	

	export UMC_TEST="true"
	export UMC_MOCK="true"
	export UMC_TEST_LSBLK="/tests/mock-inputs/lsblk-2-efi-partitions"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	mock-efi-files

	# Insert line to configuration file for alternative entry
	echo 'KERNEL_CONFIG="%entry_id %linux_name Linux %kernel_version ; "' >> /etc/default/uefi-mkconfig

	simulate-run

	clean-test

	echo ""
	echo ""
}

test-first-run-config-generation (){
	# Test running uefi-mkconfig without config file making sure it is generated
	echo "Testing generation of new config file upon first run:"	

	export UMC_TEST="true"
	export UMC_MOCK="true"
	export UMC_TEST_LSBLK="/tests/mock-inputs/lsblk-2-efi-partitions"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	mock-efi-files

	check_output=false
	simulate-run
	check_output=true
	
	[[ -f /etc/default/uefi-mkconfig ]] && echo "Configuration has been created!"

	simulate-run

	clean-test

	echo ""
	echo ""
}

test-dry-run-config-generation (){
	# Test running uefi-mkconfig without config file making sure it is generated
	echo "Testing generation of new config file upon dry run:"	

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

	clean-test

	echo ""
	echo ""
}

test-standard-run (){
	echo "Testing standard uefi-mkconfig run:"	

	export UMC_TEST="true"
	export UMC_MOCK="true"
	export UMC_TEST_LSBLK="/tests/mock-inputs/lsblk-3-efi-partitions"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	mock-efi-files

	# Insert line to configuration file for alternative entry
	echo 'KERNEL_CONFIG="%entry_id %linux_name Linux %kernel_version ; root=/dev/sda1 "' >> /etc/default/uefi-mkconfig

	simulate-run --debug

	clean-test

	echo ""
	echo ""
}

test-legacy-config-run (){
	echo "Testing running uefi-mkconfig with legacy config format:"	

	export UMC_TEST="true"
	export UMC_MOCK="true"
	export UMC_TEST_LSBLK="/tests/mock-inputs/lsblk-2-efi-partitions"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	mock-efi-files

	# Insert line to configuration file for alternative entry
	echo 'root=/dev/sda1 test=test' >> /etc/default/uefi-mkconfig

	simulate-run

	clean-test

	echo ""
	echo ""
}

test-latest-only-run (){
	echo "Testing latest-only uefi-mkconfig run:"	

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

	clean-test

	echo ""
	echo ""
}

test-forwardslashes (){
	echo "Testing forwardslashes uefi-mkconfig run:"	

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

	clean-test

	echo ""
	echo ""
}

test-boot-efi-mountpoint (){
	echo "Testing boot-efi-mountpoint test uefi-mkconfig run:"	

	# Created because of issue #39

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

	clean-test

	echo ""
	echo ""
}

test-backup-entries-run (){
	echo "Testing backups entries run:"	

	export UMC_TEST="true"
	export UMC_MOCK="true"
	export UMC_TEST_LSBLK="/tests/mock-inputs/lsblk-2-efi-partitions"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	mock-efi-files
	
	touch /boot1/EFI/Gentoo/vmlinuz-6.11.7-gentoo-dist.efi.uefibackup

	# Insert line to configuration file for alternative entry
	echo 'KERNEL_CONFIG="%entry_id %linux_name Linux %kernel_version ; root=/dev/sda1 "' >> /etc/default/uefi-mkconfig

	simulate-run

	clean-test

	echo ""
	echo ""
}

test-verbose-and-debug-run (){
	echo "Testing verbose and debug uefi-mkconfig run:"	

	export UMC_TEST="true"
	export UMC_MOCK="true"
	export UMC_TEST_LSBLK="/tests/mock-inputs/lsblk-2-efi-partitions"
	export UMC_TEST_EFIBOOTMGR="/tests/mock-inputs/efibootmgr-no-umc-entry"

	mock-efi-files

	# Insert line to configuration file for alternative entry
	echo 'KERNEL_CONFIG="%entry_id %linux_name Linux %kernel_version ; root=/dev/sda1 "' >> /etc/default/uefi-mkconfig

	simulate-run -v --debug

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

	echo "Tested: $num_test"
	echo "Failed: $num_fail"

	[ "$num_fail" -eq "0" ]
}

if [[ -f /inside-umc-test-chroot ]]; then

	if run_tests; then
		echo "Passed"
		exit 0
	else
		echo "Fail"
		exit 1
	fi

else
	echo "Not in test chroot, stopping. Run run_chroot_tests.sh to tun these tests in safe chroot!"
	exit 2
fi
