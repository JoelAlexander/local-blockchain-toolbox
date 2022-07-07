Bootstrapping:

To get NixOS installed on a Raspberry Pi:
https://nix.dev/tutorials/installing-nixos-on-a-raspberry-pi
https://schauderbasis.de/posts/install_nixos_on_raspberry_pi_4/

You may need to reformat the SD card using fdisk to have a single Linux partition

sudo dd if=~/Downloads/nixos-sd-image-20.09.4409.66b0db71f46-aarch64-linux.img of=/dev/mmcblk0 status=progress



Procedure:
0. ssh into host and get the tar.gz (What is ip/hostname?, where to get tar.gz)
1. ./install.sh
2. newgrp docker
3. ./make-docker-images.sh

Split network setup from blockchain setup?

4. ./create-local-blockchain.sh

Split blockchain setup from site setup?

5. ./run-local-blockchain.sh



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
