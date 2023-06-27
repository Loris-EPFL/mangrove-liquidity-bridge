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

    function setUp() public override {
        super.setUp();

        fee = 3000;

        base = loadToken("WBTC");

        quote = loadToken("USDT");
    }

    function setDex() private {
        console2.log("DexUniV3Test/setUp/profile", profile);

        builder = new UniV3PoolBuilder(base, quote, fee);
        require(address(builder.pool()) != address(0), "Pool address is not 0");

        dex = new DexUniV3(address(builder.pool()));
        console2.log(
            "DexUniV3Test/setUp/baseIsToken0",
            address(base) < address(quote)
        );

        builder.initiateLiquidity(
            larry,
            ud(25_000e18),
            ud(100_000e18),
            ud(23_000e18),
            ud(27_000e18)
        );
    }

    function testInitPoolWBTCUSDT() public {
        setDex();

        base = loadToken("USDC");
        quote = loadToken("WBTC");
        UD60x18 midPrice = dex.currentPrice(address(base), address(quote));
        console2.log(
            "DexUniV3Test/testGetMidPrice/midPrice",
            midPrice.unwrap()
        );
        assertLt(midPrice.unwrap(), ud(30_000e18).unwrap());
        assertGt(midPrice.unwrap(), ud(20_000e18).unwrap());
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

        console2.log("Alice quote balance", quote.balanceOf(alice));
    }
}
