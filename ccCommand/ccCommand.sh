#!/bin/bash
# creditcoin command selection

# Global variables. These may be different depending on your environment
# SERVER_COMPOSE_FILE="./Server/creditcoin-with-gateway.yaml"
# CLIENT_COMPOSE_FILE="./Client/creditcoin-client.yaml"
# VALIDATOR_CONTAINER="sawtooth-validator-default"
# CLIENT_CONTAINER="creditcoin-client"

SERVER_COMPOSE_FILE="./Server/docker-compose.yaml"
CLIENT_COMPOSE_FILE="./Client/docker-compose.yaml"
VALIDATOR_CONTAINER="sawtooth-validator-default"
CLIENT_CONTAINER="creditcoin-client"

until [ "$opt" = "0" ] 
do
	CurBlkNum=0
	PreBlkNum=0
	CurPeerNum=0
	CurSrvBlkNum=0

	echo "========================================================================="
	echo "1. Start Creditcoin server and client"
	echo "2. Check docker container statuses"
	echo "3. Monitor block height every 10 minutes (press Ctrl+C to quit)"
	echo "4. Monitor block height and restart if height is stagnant for an hour"
	echo "5. Check mining history from my server's perspective (press Ctrl+C to quit)"
	echo "6. Print validator debug messages (press Ctrl+C to quit)"
	echo "7. Monitor server peer status (press Ctrl+C to quit)"
	echo "8. Terminate Creditcoin server and client"
	echo "9. Print private key/public key/sighash"
	echo "0. Quit this script"
	echo "-------------------------------------------------------------------------"
	printf "Enter an option, then press Enter : "

	read opt

	echo "========================================================================="

	case $opt in 
		1)
			echo "Starting Server&Client docker containers..."
			docker-compose -f $SERVER_COMPOSE_FILE up -d
			sleep 1
			docker-compose -f $CLIENT_COMPOSE_FILE up -d
			sleep 1
			;;
		2)
			echo "docker container's status are as following..."
			docker container ls 
			;;
		3)
			echo "Monitoring Block height every 10 minute..."

			while true
            do
                CurBlkNum=$(docker exec $CLIENT_CONTAINER ./ccclient tip | awk '/^[0-9]/{print int($0)}' | xargs echo -n)
                CurPeerNum=$(curl http://localhost:8008/peers 2>/dev/null | grep tcp | wc -l | xargs echo -n)
                CurSrvBlkNum=$(curl https://api.creditcoin.org/api/blockchain 2>/dev/null | grep 'blockHeight' | awk -F[:,] '{gsub("\"", ""); print $2}' | xargs echo -n)
                echo "$(date "+%Y-%m-%d %H:%M:%S") | [Server] $CurBlkNum | [Network] $CurSrvBlkNum | [Peers] $CurPeerNum"
                sleep 600
            done
            ;;
		4)
			while true
			do
				CurBlkNum=$(docker exec $CLIENT_CONTAINER ./ccclient tip | awk '/^[0-9]/{print int($0)}')

				if [ "$PreBlkNum" -eq 0 ]
				then
					echo "$(date "+%Y-%m-%d %H:%M:%S") | The Block height is $CurBlkNum."
				elif [ "$PreBlkNum" -eq "$CurBlkNum" ]
				then
					echo "$(date "+%Y-%m-%d %H:%M:%S") | Restarting Server & Client containers as current block height is same as one hour ago..."
					docker-compose -f $CLIENT_COMPOSE_FILE down
					sleep 1
					docker-compose -f $SERVER_COMPOSE_FILE down
					sleep 1
					docker-compose -f $SERVER_COMPOSE_FILE up -d
					sleep 1
					docker-compose -f $CLIENT_COMPOSE_FILE up -d
					sleep 1
				else
					echo "$(date "+%Y-%m-%d %H:%M:%S") | The block height of one hour ago is $PreBlkNum, now is $CurBlkNum."
				fi

				PreBlkNum=$CurBlkNum
				sleep 3600
			done
			;;
		5)
			echo "Mining history of this server's perspective is as following..."
			echo "Please note that mining history of ledger's perspective could be different to this."
			pub=$(docker exec $VALIDATOR_CONTAINER sh -c "cat /etc/sawtooth/keys/validator.pub")
			docker exec $VALIDATOR_CONTAINER bash -c "sawtooth block list --url http://rest-api:8008 -F csv" | grep $pub | awk -F, 'BEGIN{printf("BLKNUM	SIGNER\n")} {printf("%s\t%s\n", $1, $5)}'
			;;
		6)
            echo "If no debug message printed, please check 'sawtooth-validator -vv' in 'Server/docker-compose.yaml', instead of 'sawtooth-validator'."
            valog=$(docker inspect --format='{{.LogPath}}' $VALIDATOR_CONTAINER)
            sudo tail -f ${valog}
            ;;

		7)
			echo "Checking peers list & status every minute..."
			while true
			do
				timestamp() {
				  ts=`date +"%Y-%m-%d %H:%M:%S"`
				  echo -n $ts
				}
				REST_API_ENDPOINT=localhost:8008
				peers=`curl http://$REST_API_ENDPOINT/peers 2>/dev/null | grep tcp:// | cut -d \" -f2 | sed 's/^.*\///'`
				# For dynamic peering, need to log nc probe results to view history of connected peers over time.
				for p in $peers; do
				  ipv4_address=`echo $p | cut -d: -f1`
				  port=`echo $p | cut -d: -f2`
				  timestamp
				  preamble=" Peer $ipv4_address:$port is"
				  if nc -z $ipv4_address $port
				  then
				    echo "$preamble open"
				  else
				    echo "$preamble closed"
				  fi
				done
			sleep 60
			done | tee -a ctcpeer.result
			;;
		8)
			echo "Terminating Server & Client docker containers..."
			docker-compose -f $CLIENT_COMPOSE_FILE down
			sleep 1
			docker-compose -f $SERVER_COMPOSE_FILE down
			sleep 1
			;;
		9)
            echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!WARNING!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" 
            echo "!YOU NEED TO TAKE EXTREME CAUTION TO SHARE THESE KEY WITH OTHERS, !"
            echo "!BECAUSE YOUR ASSETS WILL BE STOLEN, ONCE YOUR PRIVATE KEY LEAKED.!"
            echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!WARNING!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" 
	    echo "###       Private Key     ###"
            docker exec $VALIDATOR_CONTAINER cat /etc/sawtooth/keys/validator.priv | grep "[0-9]"
            echo "###       Public Key      ###"
            docker exec $VALIDATOR_CONTAINER cat /etc/sawtooth/keys/validator.pub | grep "[0-9]"
            echo "###       SigHash         ###"
            docker exec $CLIENT_CONTAINER ./ccclient sighash | grep "[0-9]"
            ;;
		0)
			break
			;;
		*)
			echo "This option is not available."
			;;
	esac
	echo ""
done
