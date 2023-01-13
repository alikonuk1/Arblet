source .env

forge script script/Arblet.s.sol:ArbletScript --rpc-url $GOERLI_RPC_URL \
    --broadcast --etherscan-api-key $ETHERSCAN_KEY \
    --verify -vvvv