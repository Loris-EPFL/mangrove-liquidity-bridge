# mangrove-liquidity-bridge

This repo exposes a liquidity bridge logic (`LiquidityBridge.sol`), from an
on-chain exchange (`IDexLogic.sol`), typically a Uniswap pool, to a mangrovian
order-book.

## Installation

1. Clone
2. Run `npm install`
3. [Install foundry](https://book.getfoundry.sh/getting-started/installation)
4. Build/compile with `npm run build` (for the details, see `package.json`.) 

## How to use it

1. Provide/Create an `.env` file following `.envdist` format
2. Specify the chain to test (polygon or mumbai) by setting `FOUNDRY_PROFILE` to `polygon` or `mumbai`
3. Run `npm run anvil` to fork the chain
4. Run `source .env; forge test -f $LOCAL_URL` to run the tests

## Notes

(IN HEAVILY PROGRESS) The current repos does not allow to test the full bridge
logic on the same chain because :

- on polygon : we don't have a Mangrove order-book deployed
- on mumbai : ~~we don't have a Uniswap pool deployed~~

## Next steps

- Finer estimation of require gas at contract creation (`LiquidityBridge`)
- Better specification for `askPivot` and `bidPivot` (when creating/refreshing
  orders)?
- What about creating an Abritageur Role (in addition to the Admin role)?
- Implement a faster reneg (for DexUniV3)
- Implement a **tenacity** behavior (taking reneg cost into acount and avoid
  certain renegs when more expensive than bridging)
- Add convenient functions to TestContext (check MangroveTest before)