#!/bin/bash
while :
do
if [[ $(pidof KontentumNC | wc -l) -eq 0 ]]; then
    sudo /home/pi/KontentumNC/bin/KontentumNC #run the kontentum client if not already running - (check folder)
fi
sleep 2
done
