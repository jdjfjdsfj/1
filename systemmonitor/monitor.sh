#!/bin/sh
# System Monitor - outputs device stats in parseable format
# Each section starts with ===SECTION=== and contains key:value pairs
# End marker: ===END===

INTERVAL="${1:-2}"

# Print header to confirm script is running
echo "===READY==="

while true; do
    echo "===STATS_START==="

    # --- CPU ---
    echo "===CPU==="
    # Read first line only (aggregate)
    read -r cpu_line < /proc/stat
    echo "cpu:$cpu_line"
    # Also get load average
    read -r loadavg < /proc/loadavg 2>/dev/null
    echo "loadavg:$loadavg"

    # --- Memory ---
    echo "===MEM==="
    cat /proc/meminfo

    # --- Disk ---
    echo "===DISK==="
    df -k / /userdisk /userdata /uresource 2>/dev/null

    # --- Battery ---
    echo "===BATTERY==="
    for f in capacity status voltage_now current_now temp health charge_full charge_now charge_counter; do
        path="/sys/class/power_supply/battery/$f"
        if [ -f "$path" ]; then
            val=$(cat "$path" 2>/dev/null)
            echo "$f:$val"
        fi
    done
    # Battery uevent for extra info
    if [ -f "/sys/class/power_supply/battery/uevent" ]; then
        cat /sys/class/power_supply/battery/uevent
    fi

    # --- eMMC ---
    echo "===EMMC==="
    if [ -f "/sys/kernel/debug/mmc1/mmc1:0001/ext_csd" ]; then
        # Life time estimation type A: bytes 537-538
        lta=$(cut -c 537-538 /sys/kernel/debug/mmc1/mmc1:0001/ext_csd 2>/dev/null)
        echo "life_time_a:0x$lta"
    fi
    if [ -f "/sys/block/mmcblk1/device/life_time" ]; then
        echo "life_time:$(cat /sys/block/mmcblk1/device/life_time)"
    fi
    if [ -f "/sys/block/mmcblk1/device/pre_eol_info" ]; then
        echo "pre_eol:$(cat /sys/block/mmcblk1/device/pre_eol_info)"
    fi
    if [ -f "/sys/block/mmcblk1/device/name" ]; then
        echo "name:$(cat /sys/block/mmcblk1/device/name)"
    fi
    if [ -f "/sys/block/mmcblk1/device/fwrev" ]; then
        echo "fwrev:$(cat /sys/block/mmcblk1/device/fwrev)"
    fi

    # --- Uptime ---
    echo "===UPTIME==="
    cat /proc/uptime

    # --- Temp ---
    echo "===TEMP==="
    if [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
        echo "thermal:$(cat /sys/class/thermal/thermal_zone0/temp)"
    fi
    # Check for other thermal zones
    for tz in /sys/class/thermal/thermal_zone*/temp; do
        if [ -f "$tz" ]; then
            zone=$(echo "$tz" | grep -o 'thermal_zone[0-9]*')
            echo "$zone:$(cat "$tz" 2>/dev/null)"
        fi
    done

    echo "===STATS_END==="
    sleep "$INTERVAL"
done
