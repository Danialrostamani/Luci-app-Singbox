#!/bin/sh
# luci-app-singbox - online installer
# Copyright (C) 2026 Danial Rostamani. All rights reserved. See LICENSE.
# https://github.com/Danialrostamani/Luci-app-Singbox
#
# Install / upgrade (settings are kept):
#   wget -O /tmp/sb-install.sh https://raw.githubusercontent.com/Danialrostamani/Luci-app-Singbox/main/install.sh && sh /tmp/sb-install.sh
#
# Other actions:
#   sh /tmp/sb-install.sh uninstall    remove the app (keeps /etc/singbox and /etc/config/singbox)
#   sh /tmp/sb-install.sh purge        remove the app and all its data
#
# Environment:
#   GH_PROXY=https://ghfast.top/   download through a GitHub mirror
#   NO_CORE_UPDATE=1               keep the OpenWrt sing-box package instead of the latest GitHub core
#   NO_DEPS=1                      do not install packages (offline upgrade)

set -e

REPO="Danialrostamani/Luci-app-Singbox"
BRANCH="main"
FILE="luci-app-singbox.tar.gz"
WORK="/tmp/luci-app-singbox-install"

msg()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*"; exit 1; }

[ -f /etc/openwrt_release ] || die "This is not OpenWrt."
[ "$(id -u)" = "0" ] || die "Run as root."

# curl is not part of a fresh OpenWrt image; uclient-fetch (wget) is
fetch() {
	if command -v curl >/dev/null 2>&1; then
		curl -fsSL --connect-timeout 15 --retry 2 -m 300 -o "$2" "$1"
	else
		wget -q -T 30 -O "$2" "$1"
	fi
}

download() {
	for url in \
		"${GH_PROXY}https://raw.githubusercontent.com/$REPO/$BRANCH/$FILE" \
		"${GH_PROXY}https://github.com/$REPO/raw/$BRANCH/$FILE" \
		"https://cdn.jsdelivr.net/gh/$REPO@$BRANCH/$FILE"; do
		msg "Downloading $url"
		rm -f "$WORK/$FILE"
		if fetch "$url" "$WORK/$FILE" && tar tzf "$WORK/$FILE" >/dev/null 2>&1; then
			return 0
		fi
		warn "failed, trying the next source"
	done
	return 1
}

rm -rf "$WORK"
mkdir -p "$WORK"
download || die "Could not download $FILE. Check the internet connection or set GH_PROXY (e.g. GH_PROXY=https://ghfast.top/)."

tar xzf "$WORK/$FILE" -C "$WORK"
INNER="$(ls "$WORK"/*/install.sh 2>/dev/null | head -n 1)"
[ -n "$INNER" ] || die "The archive does not contain install.sh."

VER="$(cat "$(dirname "$INNER")/VERSION" 2>/dev/null || echo '?')"
msg "luci-app-singbox $VER"

rc=0
sh "$INNER" "$@" </dev/null || rc=$?
rm -rf "$WORK"
exit $rc
