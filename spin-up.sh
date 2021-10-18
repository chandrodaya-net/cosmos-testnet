#!/bin/sh

BINARY=junod
BINARY_IMAGE=cosmoscontracts/juno:latest
CHAINID=test-chain-id	
CHAINDIR=./workspace	

KBT="--keyring-backend=test"

echo "Creating $BINARY instance with home=$CHAINDIR chain-id=$CHAINID..."	

# Build genesis file incl account for passed address	
DENOM="ucoin"
MAXCOINS="100000000000"$DENOM
COINS="90000000000"$DENOM	

clean_setup(){
    echo "rm -rf $CHAINDIR"
    echo "rm -f docker-compose.yaml"
    rm -rf $CHAINDIR
    rm -f docker-compose.yml
}

get_home() {
    dir="$CHAINDIR/$CHAINID/$1"
    echo $dir
}

# Initialize home directories
init_node_home () { 
    echo "init_node_home $1"
    home=$(get_home $1)
    $BINARY --home $home --chain-id $CHAINID init $1 &>/dev/null	
}

# Add some keys for funds
keys_add() {
    echo "keys_add $1"
    home=$(get_home $1)
    $BINARY --home $home keys add $1 $KBT &>> $home/config/account.txt	
}

# Add addresses to genesis
add_genesis_account() {
    echo "add_genesis_account $1"
    home=$(get_home $1)
    $BINARY --home $home add-genesis-account $($BINARY --home $home keys $KBT show $1 -a) $MAXCOINS  $KBT &>/dev/null	
}

# Create gentx file
gentx() {
    echo "gentx: $1"
    home=$(get_home $1)
    $BINARY --home $home gentx $1 $COINS  --chain-id $CHAINID $KBT &>/dev/null	
}

add_genesis_account_to_node0() {
    echo "add_genesis_account_to_node0: $1"
    home=$(get_home $1)
    home0=$(get_home node0)
    $BINARY --home $home0 add-genesis-account $($BINARY --home $home keys $KBT show $1 -a) $MAXCOINS  $KBT &>/dev/null	
}

copy_all_gentx_and_add_genesis_account_to_node0(){
    echo "copy_all_gentx_and_add_genesis_account_to_node0"
    dir0=$(get_home node0)
    n=1
    while ((n < $1)); do
        nodeName="node$n"
        dir=$(get_home $nodeName)
        cp $dir/config/gentx/*  $dir0/config/gentx 
        add_genesis_account_to_node0 $nodeName
        let n=n+1
    done
}

# create genesis file. node0 needs to execute this cmd
collect_gentxs_from_node0(){
    echo "collect_gentxs_from_node0"
    home=$(get_home node0)
    $BINARY --home $home collect-gentxs &>/dev/null	
    echo "$home/config/genesis.json"
}


copy_genesis_json_from_node0_to_other_node(){
    echo "copy_genesis_json_from_node0_to_other_node"
    home0=$(get_home node0)
    n=1
    while ((n < $1)); do
        nodeName="node$n"
        home=$(get_home $nodeName)
        cp $home0/config/genesis.json  $home/config/
        let n=n+1
    done
}

replace_stake_denomination(){
    echo "replace denomination in genesis: stake->$DENOM"
    home0=$(get_home node0)
    sed -i "s/\"stake\"/\"$DENOM\"/g" $home0/config/genesis.json
}


set_persistent_peers(){
    echo "set_persistent_peers $1 $2"
    currentNodeName="node$2"
    currentNodeHome=$(get_home $currentNodeName)
    
    persistent_peers=""
    n=0
    while ((n < $1)); do
        nodeName="node$n"
        ipAddress="192.168.10.$n"
        if [ "$n" != "$2" ]; then
            home=$(get_home $nodeName)
            peer="$($BINARY --home $home tendermint show-node-id)@${ipAddress}:26656"
            if [ "$persistent_peers" != "" ]; then 
                persistent_peers=$persistent_peers","$peer ;
            else
                persistent_peers=$peer
            fi 
        fi 

        let n=n+1
    done

   echo $currentNodeHome
   echo $persistent_peers
   sed -i "s/^persistent_peers *=.*/persistent_peers = \"$persistent_peers\"/" $currentNodeHome/config/config.toml
   
}
 

set_persistent_peers_all_nodes() {
    echo "set_persistent_peers_all_nodes"
    node=0
    while ((node < $1)); do
        set_persistent_peers $1 $node 
        let node=node+1
    done
}


init_node () {
    n=0
    while ((n < $1)); do
        nodeName="node$n"
        echo "########## $nodeName ###############" 
        init_node_home $nodeName
        keys_add $nodeName
        add_genesis_account $nodeName
        gentx $nodeName
        #set_persistent_peers $1 $n
        let n=n+1
    done

    echo "########## generate genesis.json ###############"
    copy_all_gentx_and_add_genesis_account_to_node0 $1 
    collect_gentxs_from_node0
    replace_stake_denomination
    copy_genesis_json_from_node0_to_other_node $1
    set_persistent_peers_all_nodes $1
} 

generate_docker_compose_file(){
    echo -e "version: '3'\n"
    echo -e "services:"

    n=0
    portStart=26656
    portEnd=26657

    while ((n < $1)); do
        nodeName="node$n"
       
        echo " $nodeName:"
        echo "   container_name: $nodeName"
        echo "   image: $BINARY_IMAGE"
        echo "   ports:"
        echo "   - \"$portStart-$portEnd:26656-26657\""
        echo "   volumes:"
        echo "   - ./workspace:/workspace"
        echo "   command: /bin/sh -c 'junod start --home /workspace/test-chain-id/$nodeName'"
        echo "   networks:"
        echo "     localnet:"
        echo -e "       ipv4_address: 192.168.10.$n\n"
    
        let n=n+1
        let portStart=portEnd+1
        let portEnd=portStart+1
    done

    echo "networks:"
    echo "  localnet:"
    echo "    driver: bridge"
    echo "    ipam:"
    echo "      driver: default"
    echo "      config:"
    echo "      -"
    echo "        subnet: 192.168.10.0/16"

}


setup_nodes(){
    clean_setup
    init_node $1
    echo "generate_docker_compose_file"
    generate_docker_compose_file $1 &> docker-compose.yml
}


repl() {
PS3='Please enter your choice: '
options=("setup nodes" "init nodes" "clean setup" "docker compose file" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "setup nodes")
            read -p "number of node: " nr
            setup_nodes $nr
            ;;
        "init nodes")
            read -p "number of node: " nr

            init_node $nr
            ;;
        "clean setup")
           clean_setup
            ;;
        "docker compose file")
            read -p "number of node: " nr
            generate_docker_compose_file $nr &> docker-compose.yml
            ;;
        "Quit")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

}

"$@"




#apk add curl
#apk add jq
#junod query staking validators --limit 1000 -o json | jq -r '.validators[] | select(.status=="BOND_STATUS_BONDED") | [.operator_address, .status, (.tokens|tonumber / pow(10; 6)), .description.moniker] | @csv' | column -t -s"," | sort -k3 -n -r | nl


# # Copy priv validator over from node that signed gentx to the signer	
# cp $n0cfgDir/priv_validator_key.json $CHAINDIR/priv_validator_key.json	
# cd $CHAINDIR	
# ../build/horcrux create-shares ./priv_validator_key.json 2 3
# ../build/horcrux config init $CHAINID localhost:1235 --config $(pwd)/signer1/config.yaml --cosigner --peers "tcp://localhost:2223|2,tcp://localhost:2224|3" --threshold 2 --listen "tcp://0.0.0.0:2222"
# ../build/horcrux config init $CHAINID localhost:1234,localhost:1235 --config $(pwd)/signer2/config.yaml --cosigner --peers "tcp://localhost:2222|1,tcp://localhost:2224|3" --threshold 2 --listen "tcp://0.0.0.0:2223"
# ../build/horcrux config init $CHAINID localhost:1234 --config $(pwd)/signer3/config.yaml --cosigner --peers "tcp://localhost:2222|1,tcp://localhost:2223|2" --threshold 2 --listen "tcp://0.0.0.0:2224"
# cp ./private_share_1.json ./signer1/share.json	
# cp ./private_share_2.json ./signer2/share.json	
# cp ./private_share_3.json ./signer3/share.json		
# cd ..	

# # Start the gaia instances	
# ./build/horcrux cosigner start --config $CHAINDIR/signer1/config.yaml > $CHAINDIR/signer1.log 2>&1 &	
# ./build/horcrux cosigner start --config $CHAINDIR/signer2/config.yaml > $CHAINDIR/signer2.log 2>&1 &	
# ./build/horcrux cosigner start --config $CHAINDIR/signer3/config.yaml > $CHAINDIR/signer3.log 2>&1 &	
# sleep 5
# gaiad $home0 start --pruning=nothing > $CHAINDIR/$CHAINID.n0.log 2>&1 &	
# gaiad $home1 start --pruning=nothing > $CHAINDIR/$CHAINID.n1.log 2>&1 &	

# echo	
# echo "Logs:"	
# echo "  - n0 'tail -f ./data/signer1.log'"	
# echo "  - n1 'tail -f ./data/signer2.log'"	
# echo "  - n2 'tail -f ./data/signer3.log'"	
# echo "  - f0 'tail -f ./data/test-chain-id.n0.log'"	
# echo "  - f1 'tail -f ./data/test-chain-id.n1.log'"