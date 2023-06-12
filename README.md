# mangrove-liquidity-bridge

This repo exposes a liquidity bridge logic (`LiquidityBridge.sol`), from an
on-chain exchange (`IDexLogic.sol`), typically a Uniswap pool, to a mangrovian
order-book.

## How to use

1. Clone
2. `npm install`
3. [Install foundry](https://book.getfoundry.sh/getting-started/installation)
4. Provide/Create an `.env` file following `.envdist` format
5. Specify the chain to test (polygon or mumbai) by setting
6. Run `npm run anvil` to fork the chain
7. Run `source .env; forge test -f $LOCAL_URL` to run the tests

## Next steps

- Finer estimation of require gas at contract creation (`LiquidityBridge`)
- Better specification for `askPivot` and `bidPivot` (when creating/refreshing
  orders)?
- What about creating an Abritageur Role (in addition to the Admin role)?
- Implement a faster reneg (for DexUniV3)
- Implement a **tenacity** behavior (taking reneg cost into acount and avoid
  certain renegs when more expensive than bridging)
- Add convenient functions to TestContext (check MangroveTest before)