// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import {TestContext} from "./utils/TestContext.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {UniV3PoolBuilder} from "./utils/UniV3PoolBuilder.sol";
import {IERC20} from "mgv_src/MgvLib.sol";
import {ERC20Mock} from "./mock/ERC20Mock.sol";
import {MathLib} from "src/math/MathLib.sol";

contract UniV3BuilderTest is TestContext {
    address alice;
    address larry; // liquidity provider

    IERC20 base;
    IERC20 quote;

    UniV3PoolBuilder builder;

    function setUp() public override {
        super.setUp();

        alice = address(1111);
        vm.label(alice, "alice");

        larry = address(2222);
        vm.label(larry, "larry");
    }

    function buildWithMockedTokens() public {
        base = new ERC20Mock("WBTC", 18);
        vm.label(address(base), "WBTC");

        quote = new ERC20Mock("USDC", 12);
        vm.label(address(quote), "USDC");

        builder = new UniV3PoolBuilder(base, quote, 3000);
        assertTrue(
            address(builder.pool()) != address(0),
            "Pool address is not 0"
        );

        (uint amount0, uint amount1) = builder.initiateLiquidity(
            larry,
            ud(25_000e18),
            ud(100_000e18),
            ud(23_000e18),
            ud(27_000e18)
        );
        console2.log("amount0", amount0);
        console2.log("amount1", amount1);

        (uint160 sp, , , , , , ) = builder.pool().slot0();

        console2.log("slot0", sp);
        console2.log(
            "CurrentPrice",
            MathLib.toUD60x18(sp).pow(ud(2e18)).unwrap()
        );
    }

    function testBuildWithMockedTokens() public {
        buildWithMockedTokens();
    }

    function testSwapWithMockedTokens() public {
        buildWithMockedTokens();

        // deal alice & approve
        deal(address(quote), alice, N.denormalize(quote, 10_000e18));

        console2.log("alice base balance before swap", base.balanceOf(alice));
        console2.log("alice quote balance before swap", quote.balanceOf(alice));

        vm.startPrank(alice);
        quote.approve(address(builder), type(uint256).max);
        vm.stopPrank();

        builder.swap(
            alice,
            builder.pool(),
            address(quote),
            address(base),
            N.denormalize(quote, 1_000e18)
        );

        console2.log("alice base balance after swap", base.balanceOf(alice));
        console2.log("alice quote balance after swap", quote.balanceOf(alice));
    }

    function buildWithDeployedTokens() public {
        base = loadToken("WBTC");
        quote = loadToken("USDT");

        builder = new UniV3PoolBuilder(base, quote, 3000);
        assertTrue(
            address(builder.pool()) != address(0),
            "Pool address is not 0"
        );

        (uint amount0, uint amount1) = builder.initiateLiquidity(
            larry,
            ud(25_000e18),
            ud(100_000e18),
            ud(23_000e18),
            ud(27_000e18)
        );
        console2.log("amount0", amount0);
        console2.log("amount1", amount1);
    }

    function testBuildWithDeployedTokens() public {
        buildWithDeployedTokens();
    }
}
