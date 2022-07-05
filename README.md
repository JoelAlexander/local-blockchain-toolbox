Bootstrapping:

To get NixOS installed on a Raspberry Pi:
https://nix.dev/tutorials/installing-nixos-on-a-raspberry-pi
https://schauderbasis.de/posts/install_nixos_on_raspberry_pi_4/

You may need to reformat the SD card using fdisk to have a single Linux partition

sudo dd if=~/Downloads/nixos-sd-image-20.09.4409.66b0db71f46-aarch64-linux.img of=/dev/mmcblk0 status=progress

Once booted from SD card:

Need some way to remove all files including .env before running setup.

scp local-blockchain-node.tar.gz ubuntu@joelalexander.me:~/. && ssh ubuntu@joelalexander.me 'tar -xvzf local-blockchain-node.tar.gz && source ./setup.sh'



Things done on new host:
- Set initial password with passwd
- ssh nixos@nixos
- sudo -i

Add the nixos hardware channel for better harware support
- nix-channel --add https://github.com/NixOS/nixos-hardware/archive/master.tar.gz nixos-hardware
- nix-channel --update

Generate the initial config.
- nixos-generate-config

Get a password hash
- nix-shell -p mkpasswd
- mkpasswd -m sha-512
- exit

Build a configuration
- vim /etc/nixos/configuration.nix
1. Add "<nixos/hardware/raspberry-pi/4>"" to imports
2. Enable ssh
3. nixos user with password created in previous step:




Pieces that seem like they could be done as a service before giving the computer to community host:
1. Setup of system image to automatically connect to wifi
2. Production of a "setup your node"
	1. Your device's MAC address.
	2. Your password

This requires the image to be built using the .nix configuration and then be booted to inspect MAC address, and configure community host's WIFI password.

Once community host receives the node they:
1. Perform the node setup on their router.
2. Power on the node.
3. Navigate to http://node-name

As a product there are two routes:
1.  Either you trust me and I set up your node and send it to you and you can skip the setup steps.  The steps taken here are exactly as written in the self serve instructions.
2.  Or you bootstrap build the node from the .nix configuration which is included in the repository.
