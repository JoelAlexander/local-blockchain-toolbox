const fs = require('fs');

// Function to create genesis file
function createGenesis(chainId, sealerAddress, allocAddress) {
    const extraData = `0x0000000000000000000000000000000000000000000000000000000000000000${sealerAddress}0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000`;
    
    const genesis = {
        "config": {
            "chainId": parseInt(chainId),
            "homesteadBlock": 0,
            "eip150Block": 0,
            "eip150Hash": "0x0000000000000000000000000000000000000000000000000000000000000000",
            "eip155Block": 0,
            "eip158Block": 0,
            "byzantiumBlock": 0,
            "constantinopleBlock": 0,
            "petersburgBlock": 0,
            "istanbulBlock": 0,
            "berlinBlock": 0,
            "londonBlock": 0,
            "clique": {
                "period": 6
            }
        },
        "difficulty": "1",
        "gasLimit": "8000000",
        "extraData": extraData,
        "nonce": "0x0",
        "alloc": {}
    };

    genesis.alloc[allocAddress] = {
        "balance": "1000001000000000000000000"
    };

    return genesis;
}

// Parsing command line arguments
const chainId = process.argv[2];
const sealerAddress = process.argv[3].replace("0x", "");
const allocAddress = process.argv[4] ? process.argv[4] : process.argv[3];
const outputPath = process.argv[5];

// Validate outputPath
if (!outputPath) {
    console.error("Output path for genesis file is required.");
    process.exit(1);
}

// Create genesis file
const genesis = createGenesis(chainId, sealerAddress, allocAddress);

// Write genesis to the specified file
fs.writeFileSync(outputPath, JSON.stringify(genesis, null, 2));
console.log(`Genesis file created at ${outputPath}`);
