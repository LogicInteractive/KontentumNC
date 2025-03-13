#!/bin/bash
crash_count=0
start_time=$(date +%s)

while true; do
    if [ ! -x /home/pi/KontentumNC/KontentumNC ]; then
        echo "ERROR: KontentumNC not executable"
        sleep 60
        exit 1
    fi

    echo "Starting KontentumNC: Attempt $((crash_count))"
    sudo /home/pi/KontentumNC/KontentumNC
    crash_count=$((crash_count + 1))
    
    if [ $crash_count -gt 5 ] && [ $(($(date +%s) - start_time)) -gt 300 ]; then
        echo "Rebooting after 5 crashes and 5 minute grace period"
        sudo reboot
        exit
    fi
    sleep 10
done