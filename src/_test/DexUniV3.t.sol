// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import {TestContext} from "./utils/TestContext.sol";
import {IERC20} from "mgv_src/MgvLib.sol";
import {DexUniV3} from "src/DexLogic/DexUniV3.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {ERC20Normalizer} from "src/ERC20Normalizer.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {UniV3PoolBuilder} from "./utils/UniV3PoolBuilder.sol";
import "src/math/MathLib.sol";
import "src/math/TickMath.sol";
import "src/univ3/LiquidityAmounts.sol";

contract DexUniV3Test is TestContext {
    DexUniV3 dex;
    IERC20 base;
    IERC20 quote;
    uint24 fee;
    UniV3PoolBuilder builder;
    address alice;
    address larry; // larry is the liquidity provider

    function setUp() public override {
        super.setUp();

        alice = address(1111);
        vm.label(alice, "alice");

        larry = address(2222);
        vm.label(larry, "larry");

        fee = 3000;

        base = loadToken("WBTC");

        quote = loadToken("USDT");
    }

    function setDex() private {
        console2.log("DexUniV3Test/setUp/profile", profile);

        address swapRouteur = loadAddress("UNIV3_ROUTER");
        vm.label(swapRouteur, "UniV3-routeur");

        builder = new UniV3PoolBuilder(base, quote, fee);
        require(address(builder.pool()) != address(0), "Pool address is not 0");

        dex = new DexUniV3(swapRouteur, address(builder.pool()));
        console2.log(
            "DexUniV3Test/setUp/baseIsToken0",
            address(base) < address(quote)
        );

        (uint amount0, uint amount1) = builder.initiateLiquidity(
            larry,
            ud(25_000e18),
            ud(100_000e18),
            ud(23_000e18),
            ud(27_000e18)
        );
    }

    //    function testWBTC_USD_midPrice_above_10_000() public {
    //base = loadToken("WBTC");
    //quote = loadToken("USDT");
    //setDex(3000);
    //checkOrCreatePool(ud(20000e18), ud(1e24));

    //UD60x18 midPrice = dex.currentPrice(address(base), address(quote));
    //console2.log(
    //"DexUniV3Test/testGetMidPrice/midPrice",
    //midPrice.unwrap() / 1e13
    //);
    //assertGt(midPrice.unwrap(), ud(10000).unwrap());
    //}

    function testUSDC_WBTC_midPrice_below_1() public {
        setDex();

        base = loadToken("USDC");
        quote = loadToken("WBTC");
        UD60x18 midPrice = dex.currentPrice(address(base), address(quote));
        console2.log(
            "DexUniV3Test/testGetMidPrice/midPrice",
            midPrice.unwrap()
        );
        assertLt(midPrice.unwrap(), ud(1e18).unwrap());
    }

    function testSellWBTC() public {
        setDex();

        UD60x18 amount = ud(1e18);

        deal(address(base), alice, N.denormalize(base, amount.unwrap()));

        vm.prank(alice);
        //base.approve(address(dex), N.denormalize(base, amount.unwrap()));
        base.approve(address(dex), type(uint256).max);
        vm.prank(alice);
        dex.swap(address(base), address(quote), amount, ud(0));
    }
}
