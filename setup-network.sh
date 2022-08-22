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
if [ $wirelessStatus = "disconnected" ]
then
  # TODO: Scan for and suggest whileifi networks
  while [ $wirelessStatus = "disconnected" ]
  do
    echo -n "Enter wireless network name (SSID): "
    read ssid
    echo -n "Enter wireless network password: "
    read wirelessPassword
    sudo nmcli dev wifi connect $ssid password $wirelessPassword > /dev/null
    wirelessStatus=$(nmcli dev status | awk -v devRegex="^$wirelessInterface" 'match($0, devRegex) { print $3 }')
  done
fi

macAddress=$(nmcli dev show $wirelessInterface | awk '/GENERAL.HWADDR/ { print $2 }')
gateway=$(nmcli dev show $wirelessInterface | awk '/IP4.GATEWAY/ { print $2 }')
ipAddress=$(nmcli dev show $wirelessInterface | awk '/IP4.ADDRESS/ { print $2 }' | sed -e 's/\/.*//')

echo "Before proceding: "
echo "Access the admin panel on your router: http://$gateway"
echo "Give $macAddress a static IP of $ipAddress"
