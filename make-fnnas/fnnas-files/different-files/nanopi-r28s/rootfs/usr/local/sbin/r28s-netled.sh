#!/bin/sh
# NanoPi R28S - bind the WAN/LAN port LEDs to the netdev LED trigger.
#
# The board has exactly three GPIO LEDs (gpio4 PB0 / PB1 / PB3):
#   PB0 -> SYS  (red,   heartbeat, handled by the DTB)
#   PB1 -> WAN  (green, next to the gmac1 / RTL8211F port)
#   PB3 -> LAN  (green, next to the PCIe / RTL8111H port)
#
# The DTB declares the two port LEDs with "linux,default-trigger = netdev",
# but a netdev trigger does nothing until an interface name is assigned to
# it, and nothing in fnOS does that - so both port LEDs stay dark forever.
# (The vendor FriendlyWrt/BSP images do this from userspace; fnOS does not.)
#
# This script assigns eth0 -> WAN LED and eth1 -> LAN LED, enabling the
# link / tx / rx indication modes. It is idempotent and safe to run at any
# time (boot, udev hotplug, or manually over SSH).

wait_for() {
	# wait_for <path> [tries of 0.2s]
	i=0
	limit="${2:-25}"
	while [ ! -e "$1" ]; do
		i=$((i + 1))
		if [ "$i" -gt "$limit" ]; then
			return 1
		fi
		sleep 0.2 2>/dev/null || sleep 1
	done
	return 0
}

pick_led() {
	for n in "$@"; do
		if [ -d "/sys/class/leds/$n" ]; then
			echo "$n"
			return 0
		fi
	done
	return 1
}

log() {
	if command -v logger >/dev/null 2>&1; then
		logger -t r28s-netled "$*"
	fi
}

bind() {
	netdev="$1"
	shift
	led="$(pick_led "$@")" || return 0
	d="/sys/class/leds/$led"

	echo netdev >"$d/trigger" 2>/dev/null
	echo "$netdev" >"$d/device_name" 2>/dev/null
	for m in link tx rx; do
		if [ -e "$d/$m" ]; then
			echo 1 >"$d/$m" 2>/dev/null
		fi
	done
	log "bound $led -> $netdev"
	return 0
}

wait_for /sys/class/leds 25

bind eth0 wan green:wan led-wan led_wan wan_led led1 usr_led1
bind eth1 lan green:lan led-lan led_lan lan_led led2 usr_led2

exit 0
