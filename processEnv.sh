# Process .env to export useful variables 
# List of variables created in this script:
# - FOUNDRY_PROFILE
# - Chain_Name
# - CHAIN_NAME
# - CHAIN_NODE_URL_VAR
# - NODE_URL
# - CHAIN_PRIVATE_KEY_VAR
# - PRIVATE_KEY
# - FORGE_KEYSTORE_PARAMS
# - CHAIN_ID
# - DEPLOYMENT_SCRIPT
# - OPTIMIZER_RUNS

# variables expected to be set in .env
# export chain_name=mumbai|polygon
# mirror to foundry profile
export FOUNDRY_PROFILE=$chain_name

# hangle case
export Chain_Name=$( echo "$chain_name" | awk '{print toupper(substr($0,1,1)) substr($0,2)}' )
export CHAIN_NAME=$( echo "$chain_name" | awk '{print toupper($0)}' )
echo $chain_name
echo $Chain_Name
echo $CHAIN_NAME

# defining URL?
export CHAIN_NODE_URL_VAR=${CHAIN_NAME}_NODE_URL
eval "export NODE_URL=\$$CHAIN_NODE_URL_VAR"
[ -z "$NODE_URL" ] && echo "$CHAIN_NODE_URL_VAR has not been set"

	export CHAIN_PRIVATE_KEY_VAR=${CHAIN_NAME}_PRIVATE_KEY
	eval "export PRIVATE_KEY=\$$CHAIN_PRIVATE_KEY_VAR"
	if [ -z "$PRIVATE_KEY" ]; then
		echo "$CHAIN_PRIVATE_KEY_VAR has not been set"
	else
		echo "Using private key from env var ${CHAIN_PRIVATE_KEY_VAR}"
	fi
export FORGE_KEYSTORE_PARAMS=()

# defining chain id
export CHAIN_ID=$( cast chain-id --rpc-url "$NODE_URL" )
echo "Chain id: $CHAIN_ID"

# choosing deployment script
export DEPLOYMENT_SCRIPT="${Chain_Name}ContractDeploymentScript"
export OPTIMIZER_RUNS=20000

# https://www.notion.so/mangroveexchange/onchain-deploy-Arbitrage-contract-deployment-d7126e4739ea4cb7960f1e7ae7375474
# WRITE_DEPLOY=true forge script --fork-url $chain_name $DEPLOYMENT_SCRIPT -vvv --verify --optimize --optimizer-runs=$OPTIMIZER_RUNS "${FORGE_KEYSTORE_PARAMS[@]}" --broadcast