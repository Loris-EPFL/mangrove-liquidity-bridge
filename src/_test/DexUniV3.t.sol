// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import {Test2} from "mgv_lib/Test2.sol";
import {ForkFactory} from "./utils/ForkFactory.sol";
import {GenericFork} from "mgv_test/lib/forks/Generic.sol";
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

contract DexUniV3Test is Test2 {
    GenericFork fork;

    DexUniV3 dex;
    IERC20 base;
    IERC20 quote;
    uint24 fee;
    UniV3PoolBuilder builder;

    address alice;
    address larry;

    ERC20Normalizer N;

    function setUp() public {
        fork = ForkFactory.getFork();
        fork.setUp();

        fee = 3000;

        base = IERC20(fork.get("WBTC"));
        quote = IERC20(fork.get("USDT"));

        alice = freshAddress("alice");
        larry = freshAddress("larry");

        N = new ERC20Normalizer();
    }

    function setDex() private returns (uint amount0, uint amount1) {
        builder = new UniV3PoolBuilder(fork);
        builder.createPool(base, quote, fee);
        require(address(builder.pool()) != address(0), "Pool address is not 0");

        dex = new DexUniV3(address(builder.pool()));

        (amount0, amount1) = builder.initiateLiquidity(
            larry,
            ud(25_000e18),
            ud(100_000e18),
            ud(23_000e18),
            ud(27_000e18)
        );
    }

    function testInitPoolWBTCUSDT() public {
        (uint amount0, uint amount1) = setDex();
        assertGt(amount0, 0, "Liquidity amount0 is 0");
        assertGt(amount1, 0, "Liquidity amount1 is 0");

        UD60x18 currentPrice = dex.currentPrice(address(base), address(quote));
        console2.log("currentPrice", currentPrice.unwrap());

        assertLt(currentPrice.unwrap(), ud(30_000e18).unwrap());
        assertGt(currentPrice.unwrap(), ud(20_000e18).unwrap());
    }

    function testSellWBTC() public {
        setDex();

        UD60x18 amount = ud(1e18);

        deal(address(base), alice, N.denormalize(base, amount.unwrap()));

        vm.prank(alice);
        //base.approve(address(dex), N.denormalize(base, amount.unwrap()));
        base.approve(address(dex), type(uint256).max);
        console2.log("Alice quote balance before", quote.balanceOf(alice));
        vm.prank(alice);
        dex.swap(address(base), address(quote), amount, ud(0));
        console2.log("Alice quote balance after", quote.balanceOf(alice));
    }
}
