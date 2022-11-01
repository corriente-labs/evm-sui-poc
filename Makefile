export 
LOCAL_NET_CONFIG_LOCATION ?= $(PWD)/local
SUI_COMMIT_HASH ?= df05544fb0cbd6d6db016e71e5facb5e7cc27988

.PHONY: version
version:
	./scripts/version.sh

.PHONY: build
build:
	sui move build

.PHONY: test
test:
	sui move test

.PHONY: init-local
init-local:
	mkdir -p $(LOCAL_NET_CONFIG_LOCATION) && sui genesis --working-dir $(LOCAL_NET_CONFIG_LOCATION) --force

.PHONY: start-local
start-local:
	pkill sui || true
	sui start --network.config $(LOCAL_NET_CONFIG_LOCATION)/network.yaml

.PHONY: stop-local
stop-local:
	pkill sui || true

.PHONY: publish-local
publish-local:
	sui client --client.config $(LOCAL_NET_CONFIG_LOCATION)/client.yaml publish --path ./ --gas-budget 30000 

.PHONY: start-rpc
start-rpc:
	rpc-server
