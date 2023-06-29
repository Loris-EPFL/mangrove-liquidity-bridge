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

1. Provide/Create an `.env` file following `.envdist` format
2. Specify the chain to test (polygon or mumbai) by setting `FOUNDRY_PROFILE` to `matic` or `maticmum`
3. Run `npm run anvil` to fork the chain
4. Run `source .env; forge test -f $LOCAL_URL` to run the tests (you can also
   run `npm run test`)

## Notes

- ✅ All tests are OK on `mumbai` (i.e. `FOUNDRY_PROFILE=maticmum`), including a
  bridge from a UniswapV3 pool to a Mangrove order-book.
- 🔴 On Polygon, because the repo is still expecting an already deployed
  Mangrove OB, some tests are failing.

## 📆 Next steps

- Better estimation of require gas at contract creation (`LiquidityBridge`)
  - Put this required gas into the constructor of the bridge
  orders)?
- Implement the dex logic into the Routing logic to avoid the non modularity
  coming from the gasreq at construction
- What about creating an Abritageur Role (in addition to the Admin role)?
- Implement a faster reneg (for DexUniV3)
- Implement a **tenacity** behavior (taking reneg cost into acount and avoid
  certain renegs when more expensive than bridging)
- Use MangroveTest, even if not using base/quote ?
- ~~Replace TestContext by fork + Test2~~
- Possible outcomes to handle
  - Partially filled
  - Totally filled
  - Repost Failed