## Pre-requisites

One need first to have locally a cosmos-sdk equivalent image which is defined in the `spin-up.sh` script.
In our case the image is build locally with the juno binary:

```
BINARY=junod
BINARY_IMAGE=cosmoscontracts/juno:latest
```

## Spin up a network with `v` validator and `n` nodes

Example: v=2, n=1

```bash
    make testnet nrValidator=2 nrNode=1
```

## Tear down the network

```bash
   make testnet-clean
```

## Useful cmds

```
# show all containers
  docker ps -a

# Enter inside the running container of the validator0
  docker  exec -it  validator0   /bin/sh

# Check logs of validator0
  docker logs validator0

# Check rpc of validator0 (n=0) is working (n --> port=26657+2n, check docker-compose.yml for detail)
  curl localhost:26657/status

# Check rpc validator0 (n=0) is working (n --> port=1317+n, check docker-compose.yml for detail)
  curl localhost:1317/blocks/latest

```
