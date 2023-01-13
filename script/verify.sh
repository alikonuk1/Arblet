source .env

export CONTRACT=0x1b11e14c93505e849f54c9a778bba16b293a342b

#chain id's
#gorli: 5
#poylgon: 137
#mumbai: 80001

#$(cast abi-encode "constructor(address)" 0x2B68407d77B044237aE7f99369AA0347Ca44B129)

forge verify-contract --chain-id 5 \
    --compiler-version v0.8.15+commit.e14f2714 \
    $CONTRACT src/Arblet.sol:Arblet $ETHERSCAN_API_KEY 