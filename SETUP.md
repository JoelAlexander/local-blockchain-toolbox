What's in the box?
- Raspberry Pi 4
- Power adapter
- Ethernet cable
- 32 GB Micro SD card

What you'll need:
- Mac, Linux, Windows computer with micro SD card slot
- Access to admin console of router for local wifi network
- Domain name and access to modify DNS records
- Internet access

Steps to setup a local blockchain node:
1. Load Ubuntu Server OS onto SD card with Raspberry Pi Loader
2. Plug in SD card, Ethernet and power adapter and power on Raspberry Pi
3. Start a terminal and ssh into ubuntu@ubuntu with password ubuntu.  You'll be prompted to create a new password for the node.  This password will secure your node's private key, so keep it strong, secret and safe!
4. Run the local blockchain setup script:
sh <(curl -L https://github.com/JoelAlexander/...) --daemon
