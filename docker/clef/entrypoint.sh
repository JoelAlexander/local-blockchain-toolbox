#!/bin/bash
clef --keystore .ethereum/keystore --configdir .clef --chainid $CHAIN_ID --suppress-bootwarn --nousb --rules rules.js <<EOF
$CLEF_PASSWORD
EOF
