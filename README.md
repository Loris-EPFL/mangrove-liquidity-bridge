# mangrove-liquidity-bridge

This repo exposes a liquidity bridge logic (`LiquidityBridge.sol`), from an
on-chain exchange (`IDexLogic.sol`), typically a Uniswap pool, to a mangrovian
order-book.

## 🔨 Installation

1. Clone
2. Run `npm install`
3. [Install foundry](https://book.getfoundry.sh/getting-started/installation)
4. Build/compile with `npm run build` (for the details, see `package.json`.)

## 🎹 How to use it

1. Provide/Create an `.env` file following `.envdist` format.
2. Specify the chain to test (polygon or mumbai) by setting `FOUNDRY_PROFILE` to `matic`, `polygon` or any other `chain_name`. Private keys and url will processed in `processEnv.sh` script. 
3. Run `npm run anvil` to fork the chain
4. Run `source processEnv.sh; forge test -f $NODE_URL` to run the tests (you can also
   run `npm run test`)

## 🧪Notes on tests

- ✅ All tests are OK on `mumbai` (i.e. `FOUNDRY_PROFILE=mumbai`), including a
  bridge from a UniswapV3 pool to a Mangrove order-book.
- 🔴 On Polygon some tests will fail because additional work is required to make sure that tests are run on consistent token names. Sorry for the inconvenience.

## ⛵ Deployment

To deploy a LiquidityBridge, you need to deploy the DexLogic first, then the
Bridge. Then, some administration stuff is required to fund it and activate it.

> 💡 A recommandation for testing deployment could be (i) to create a fork on
tenderly, (ii) export the corresponding url to  `POLYGON_TENDERLY_NODE_URL` in
`.env`.

💡 Here is a list of commands to run for the deployment:  
 
> ⚠️ Run them in the terminal as this a first time. If everything is ok, run them
again with `--broadcast` as additinonal argument to broadcast the transaction on
the chain.

1. Load the env variables: `source processEnv.sh`. It will set the chain, the private key, the admin (chief) address
2. Run `forge script script/DeployUniV3Bridge.s.sol -f $NODE_URL -s "deployDexLogic()" --private-key $PRIVATE_KEY`. 
3. Save the DexLogic address in the `.env` file as `DEXLOGIC`
4. Run `forge script script/DeployUniV3Bridge.s.sol -f $NODE_URL -s "deployBridge()" --private-key $PRIVATE_KEY`. Note that Bridge parameters used for deployment are part of the `DeployUniV3Bridge.s.sol` file.
5. Save the Bridge address in the `.env` file as `BRIDGE`
6. Now the following commands will fund, activate and deploy the offers of the bridge:
7. Run `forge script script/BridgeAdmin.s.sol  -f $NODE_URL --private-key
   $PRIVATE_KEY -s "fund()"`. Note that funded amount are in the
   `BridgeAdmin.s.sol` file.
8. Run `forge script script/BridgeAdmin.s.sol -f $NODE_URL --private-key $PRIVATE_KEY -s "activate()"`
9. Run `forge script script/BridgeAdmin.s.sol  -f $NODE_URL --private-key $PRIVATE_KEY -s "newOffers()"`

Your brigde should now be ready to use.

## 📆 Next steps

- Gas estimation : I recommand to use the gas profile tool to estimate gas
  taking an order of the Bridge. This part is essential because passed at the
  constructor of `Direct`.
- Improvements : 
  - Implement the dex logic into the Routing logic to avoid the non modularity
  - What about creating an Abritageur Role (in addition to the Admin role)?
  - Implement a **tenacity** behavior (taking reneg cost into acount and avoid
    certain renegs when more expensive than bridging)
  - Better custom handling of all possible path (partially/totally filled,
    repost failed, etc.)
