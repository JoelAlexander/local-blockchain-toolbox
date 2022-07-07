#!/bin/bash

# Detect wireless interface
interfaces=$(ifconfig -a | awk '/^[a-zA-Z0-9]/ { print $1 }' | sed -e 's\:\\')
for i in ${interfaces[@]}
do
  if [[ -d "/sys/class/net/${i}/wireless" ]]; then
    wirelessInterface=${i}
    break
  fi
done

if [ -z $wirelessInterface ]; then
  echo "No wireless interface was found"
  exit 1
fi

wirelessStatus=$(nmcli dev status | awk -v devRegex="^$wirelessInterface" 'match($0, devRegex) { print $3 }')
if [ "$wirelessStatus" == "disconnected" ]; then
  # TODO: Scan for and suggest whileifi networks
  while [[ "$wirelessStatus" == "disconnected" ]]; do
    read -p "Enter wireless network name (SSID): " ssid
    read -p "Enter wireless network password: " wirelessPassword
    nmcli dev wifi connect $ssid password $wirelessPassword > /dev/null
    wirelessStatus=$(nmcli dev status | awk -v devRegex="^$wirelessInterface" 'match($0, devRegex) { print $3 }')
  done
  echo "$wirelessInterface" && exit 0
elif [ "$wirelessStatus" == "connected" ]; then
  echo "$wirelessInterface"
  exit 0
fi
