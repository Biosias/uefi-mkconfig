#!/usr/bin/env bash
set -euo pipefail

if ! command -v unshare >/dev/null 2>&1; then
  >&2 echo "Error: 'unshare' is not installed or not in PATH."
  exit 1
fi

if ! unshare --user --mount --map-root-user true >/dev/null 2>&1; then
  >&2 echo "Error: unprivileged user+mount namespaces are not available on this system." >&2
  exit 1
fi

unshare --user --mount --map-root-user bash "$(dirname "$0")/run_chroot_tests.sh"