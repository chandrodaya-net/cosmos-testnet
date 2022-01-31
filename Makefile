#!/usr/bin/make -f

### Local validator nodes using docker and docker-compose
# setup config files of validators and nodes and create 
# the corresponding the docker-compose.yml
# Example: make testnet-init nrValidator=1 nrNode=0
testnet-init:
	bash  spin-up.sh setup_nodes $(nrValidator) $(nrNode)

testnet-init-debug:
	bash -x spin-up.sh setup_nodes $(nrValidator) $(nrNode)

testnet-start:
	docker-compose up -d

testnet-stop:
	docker-compose down

testnet-clean:
	docker-compose down
	sudo rm -rf  workspace 
	sudo rm docker-compose.yml 

# Example: make testnet nrValidator=1 nrNode=0
testnet: testnet-init testnet-start