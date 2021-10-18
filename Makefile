#!/usr/bin/make -f

### Local validator nodes using docker and docker-compose

testnet-init:
	bash spin-up.sh setup_nodes $(nrnode)

testnet-start:
	docker-compose up -d

testnet-stop:
	docker-compose down

testnet-clean:
	docker-compose down
	sudo rm -rf  workspace 
	sudo rm docker-compose.yml 