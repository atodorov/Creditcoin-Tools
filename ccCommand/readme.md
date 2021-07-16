# ccCommand Bash Script

## Introduction

Based on a script created by Creditcoin community member `sword` here:

https://community.creditcoin.org/t/simple-script-for-mining-maintenance-in-korean/52

## Script features

The script provides several useful features:
1. Start Creditcoin server and client
2. Check docker container statuses
3. Monitor block height every 10 minutes (press Ctrl+C to quit)
4. Monitor block height and restart if height is stagnant for an hour
5. Check mining history from my servers perspective (press Ctrl+C to quit)
6. Print validator debug messages (press Ctrl+C to quit)
7. Monitor server peer status (press Ctrl+C to quit)
8. Terminate Creditcoin server and client
9. Print private key/public key/sighash

## How to use

1. Place it under the `CreditcoinDocs-Mainnet-master` directory
2. Make it executable: `chmod +x ccCommand.sh`
3. Run it: `sudo ./ccCommand.sh` or `ccCommand.sh` (Depends whether current user is in `docker` group - See https://docs.docker.com/engine/install/linux-postinstall/ for more info)
4. Choose an option from the menu shown!