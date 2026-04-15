#!/bin/bash
mounted_dirs=""

chroot_create () {
	echo "Creating chroot environment in $TEMP_DIR"

	mount_dirs="bin lib lib64 usr/lib64 usr/sbin usr/bin"
	setup_dirs="$mount_dirs etc/default tests dev log boot1/EFI/Gentoo boot2/EFI/Gentoo boot3/EFI/Gentoo boot1/EFI/shimtest boot2/EFI/shimtest"
	
	for dir in $setup_dirs; do
		mkdir -p "$TEMP_DIR/$dir"
	done


	for dir in $mount_dirs; do
		[ -d "/$dir" ] && mount --rbind -o ro "/$dir" "$TEMP_DIR/$dir" && mounted_dirs="$mounted_dirs $dir"
	done
	
	touch "$TEMP_DIR/uefi-mkconfig"
	touch "$TEMP_DIR/dev/null"

	mount --bind -o ro "$MY_LOCATION/../uefi-mkconfig" "$TEMP_DIR/uefi-mkconfig"
	mount --bind -o ro "$MY_LOCATION/../tests" "$TEMP_DIR/tests"
	mount --bind "$MY_LOCATION/../tests/log" "$TEMP_DIR/log"
	mount --bind "/dev/null" "$TEMP_DIR/dev/null"

	touch "$TEMP_DIR/inside-umc-test-chroot"
}

chroot_destroy () {
	echo "Destroying chroot environment in $TEMP_DIR"

	mounts="$mounted_dirs uefi-mkconfig tests log dev/null"

	for mount in $mounts; do
		umount -l "$TEMP_DIR/$mount"
	done

	[[ "$TEMP_DIR" != "/" ]] && [[ "$TEMP_DIR" != "" ]] && rm -r "$TEMP_DIR"
}

MY_LOCATION="$(echo $(which ${0}) | sed 's/\/run_chroot_tests.sh//')"
TEMP_DIR="$(mktemp -d)"

chroot_create

chroot "$TEMP_DIR" /bin/bash /tests/tests_inside_chroot.sh
#chroot "$TEMP_DIR" /bin/bash

chroot_destroy
