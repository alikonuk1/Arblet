# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
install:; forge install
update:; forge update

# Build & test
build  :; forge build
test   :; forge test
trace  :; forge test -vvv
clean  :; forge clean
snapshot :; forge snapshot
gas :; forge test --gas-report

# deploy scripts
deploy-local :; . script/deploy_local.sh
dg :; . script/deploy_goerli.sh
deploy-mumbai :; . script/deploy_mumbai.sh
deploy-polygon :; . script/deploy_polygon_mainnet.sh
deploy-eth :; . script/deploy_mainnet.sh
verify :; . script/verify.sh
verify-check :; . script/verify_check.sh

# calls
