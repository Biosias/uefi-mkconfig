#!/bin/bash

chroot_create () {
	echo "Creating chroot environment in $TEMP_DIR"

	setup_dirs="bin etc/default tests dev usr/bin usr/sbin usr/lib64 lib lib64 boot1/EFI/Gentoo boot2/EFI/Gentoo boot1/EFI/shimtest boot2/EFI/shimtest"
	
	for dir in $setup_dirs; do
		mkdir -p "$TEMP_DIR/$dir"
	done

	mount_dirs="bin lib lib64 usr/lib64 usr/sbin usr/bin"

	for dir in $mount_dirs; do
		mount --rbind -o ro "/$dir" "$TEMP_DIR/$dir"
	done
	
	touch "$TEMP_DIR/uefi-mkconfig"
	touch "$TEMP_DIR/dev/null"

	mount --bind -o ro "$MY_LOCATION/../uefi-mkconfig" "$TEMP_DIR/uefi-mkconfig"
	mount --bind -o ro "$MY_LOCATION/../tests" "$TEMP_DIR/tests"
	mount --bind "/dev/null" "$TEMP_DIR/dev/null"

	touch "$TEMP_DIR/inside-umc-test-chroot"
}

chroot_destroy () {
	echo "Destroying chroot environment in $TEMP_DIR"

	mount_dirs="bin lib lib64 usr/lib64 usr/sbin tests uefi-mkconfig dev/null usr/bin"

	for dir in $mount_dirs; do
		umount "$TEMP_DIR/$dir"
	done

	[[ "$TEMP_DIR" != "/" ]] && [[ "$TEMP_DIR" != "" ]] && rm -rf "$TEMP_DIR"
}

MY_LOCATION="$(echo $(which ${0}) | sed 's/\/chroot_tests.sh//')"
TEMP_DIR="$(mktemp -d)"

chroot_create

chroot "$TEMP_DIR" /bin/bash /tests/run_tests.sh
#chroot "$TEMP_DIR" /bin/bash

chroot_destroy
