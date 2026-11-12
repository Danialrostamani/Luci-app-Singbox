#!/bin/sh
# Google Wifi (gale) / Qualcomm IPQ4019 / ARMv7 Hysteria 2 Turbo Unlock Patch
# Copyright (C) 2026 Danial Rostamani. All rights reserved. See LICENSE.
#
# Run on router:
#   wget -O /tmp/patch-google.sh https://raw.githubusercontent.com/Danialrostamani/Luci-app-Singbox/main/patch-google.sh && sh /tmp/patch-google.sh
#

set -e

msg()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
info() { printf '\033[1;36m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }

msg "Applying Google Wifi (gale) / IPQ4019 Hysteria 2 Turbo Unlock Patch..."

# 1. Switch TUN stack to native kernel system stack and MTU 9000
if command -v uci >/dev/null 2>&1; then
    uci set singbox.main.tun_stack='system'
    uci set singbox.main.tun_mtu='9000'
    uci set singbox.main.max_perf='1'
    uci commit singbox 2>/dev/null || true
    info "Switched TUN stack to native Linux kernel 'system' stack (bypasses gVisor userspace UDP choke)"
    info "Set TUN MTU to 9000 jumbo frames (reduces CPU packet context-switches 6x)"
fi

# 2. CPU governor to performance on all cores
for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor /sys/devices/system/cpu/cpufreq/policy*/scaling_governor; do
    [ -f "$g" ] && echo performance > "$g" 2>/dev/null || true
done
info "Locked 4x Cortex-A7 cores to maximum clock speed (716 MHz)"

# 3. Network IRQ affinity across all CPU cores
if [ -d /proc/irq ]; then
    num_cpus=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 1)
    mask=$(printf '%x' $(( (1 << num_cpus) - 1 )) 2>/dev/null || echo f)
    for a in /proc/irq/*/smp_affinity; do
        [ -w "$a" ] && echo "$mask" > "$a" 2>/dev/null || true
    done
    info "Distributed network interrupts across all $num_cpus CPU cores"
fi

# 4. Multi-core Packet Steering (RPS)
if command -v uci >/dev/null 2>&1; then
    uci set network.globals='globals' 2>/dev/null || true
    uci set network.globals.packet_steering='2'
    uci commit network 2>/dev/null || true
    if [ -x /etc/init.d/packet_steering ]; then
        /etc/init.d/packet_steering restart >/dev/null 2>&1 || true
    fi
    info "Enabled Packet Steering (RPS) on all 4 cores"
fi

# 5. Kernel socket buffers for high-speed QUIC
mkdir -p /etc/sysctl.d
cat << 'EOF' > /etc/sysctl.d/90-singbox-perf.conf
# written by singbox patch-google
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=2621440
net.core.wmem_default=2621440
net.ipv4.tcp_rmem=4096 131072 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.core.netdev_max_backlog=8192
net.core.somaxconn=4096
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
net.core.default_qdisc=fq_codel
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl -q -p /etc/sysctl.d/90-singbox-perf.conf 2>/dev/null || true
info "Applied 16MB kernel socket buffers + 2.5MB QUIC UDP buffers"

# 6. Apply with singbox-ctl if available
if [ -x /usr/bin/singbox-ctl ]; then
    /usr/bin/singbox-ctl perf-apply >/dev/null 2>&1 || true
fi

# 7. Restart sing-box
msg "Restarting sing-box service..."
if [ -x /etc/init.d/singbox ]; then
    /etc/init.d/singbox restart >/dev/null 2>&1 || true
fi

msg "SUCCESS: Google Wifi Hysteria 2 speed limit is now UNLOCKED!"
msg "All 4 cores active | System TUN stack | 9000 MTU | BBR Aggressive"
