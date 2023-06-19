// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import {TestContext} from "./utils/TestContext.sol";
import {IERC20} from "mgv_src/MgvLib.sol";
import {DexUniV3} from "src/DexLogic/DexUniV3.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {ERC20Normalizer} from "src/ERC20Normalizer.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

contract DexUniV3Test is TestContext {
    DexUniV3 dex;
    IERC20 base;
    IERC20 quote;
    IUniswapV3Factory factory;
    address alice = address(1111);
    address larry = address(2222); // larry is the liquidity provider

    function setUp() public {}

    function setDex(uint24 fee) public {
        console2.log("DexUniV3Test/setUp/profile", profile);

        address swapRouteur = loadAddress("UNIV3_ROUTER");
        vm.label(swapRouteur, "UniV3-routeur");

        factory = IUniswapV3Factory(loadAddress("UNIV3_FACTORY"));

        vm.label(address(factory), "UniV3-factory");
        dex = new DexUniV3(swapRouteur, address(factory), fee);
    }

    function toQ96(UD60x18 q) internal pure returns (uint160) {
        uint intPart = (q.div(ud(1e18)) << 96);
        uint fracPart = (q.mod(ud(1e18)) << 96) / 1e18;
        return uint160(intPart + fracPart);
    }

    function checkOrCreatePool(
        uint24 fee,
        UD60x18 currentPrice,
        UD60x18 quoteAmount
    ) public {
        // check if pool exists
        address poolAddr = factory.getPool(address(base), address(quote), fee);

        if (poolAddr != address(0)) {
            return;
        }

        console2.log("DexUniV3Test/setUp/creating pool");
        poolAddr = factory.createPool(address(base), address(quote), fee);

        // initialize pool and deposit
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddr);

        if (address(base) != pool.token0()) {
            currentPrice = ud(1e18) / currentPrice;
        }

        uint160 sqrtPriceX96 = uint160(100000);
        // TODO convert currentPrice to sqrtPriceX96
        pool.initialize(sqrtPriceX96);

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: address(base),
                token1: address(quote),
                fee: fee,
                tickLower: TickMath.MIN_TICK,
                tickUpper: TickMath.MAX_TICK,
                amount0Desired: N.denormalize(
                    base,
                    (quoteAmount.div(currentPrice)).unwrap()
                ),
                amount1Desired: N.denormalize(quote, quoteAmount.unwrap()),
                amount0Min: 0,
                amount1Min: 0,
                recipient: larry,
                deadline: block.timestamp
            });
        nonfungiblePositionManager.mint(params);
    }

    function testWBTC_USD_midPrice_above_10_000() public {
        setDex(3000);

        base = loadToken("WBTC");
        quote = loadToken("USDC");
        UD60x18 midPrice = dex.currentPrice(address(base), address(quote));
        console2.log(
            "DexUniV3Test/testGetMidPrice/midPrice",
            midPrice.unwrap() / 1e13
        );
        assertGt(midPrice.unwrap(), ud(10000).unwrap());
    }

    function testUSDC_WBTC_midPrice_below_1() public {
        setDex(3000);

        base = loadToken("USDC");
        quote = loadToken("WBTC");
        UD60x18 midPrice = dex.currentPrice(address(base), address(quote));
        console2.log(
            "DexUniV3Test/testGetMidPrice/midPrice",
            midPrice.unwrap() / 1e13
        );
        assertLt(midPrice.unwrap(), ud(1e18).unwrap());
    }

    function testSellWBTC() public {
        setDex(3000);
        base = loadToken("WBTC");
        quote = loadToken("USDC");

        UD60x18 amount = ud(1e18);

        deal(address(base), alice, N.denormalize(base, amount.unwrap()));

        vm.prank(alice);
        //base.approve(address(dex), N.denormalize(base, amount.unwrap()));
        base.approve(address(dex), type(uint256).max);
        vm.prank(alice);
        dex.swap(address(base), address(quote), amount, ud(0));
    }
}
