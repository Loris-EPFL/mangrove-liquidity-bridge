// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import {LiquidityBridgeContext} from "./utils/LiquidityBridgeContext.sol";

import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {MgvStructs} from "mgv_src/MgvLib.sol";
import {UniV3PoolBuilder} from "./utils/UniV3PoolBuilder.sol";
import {DexUniV3} from "src/DexLogic/DexUniV3.sol";

contract LiquidityBridgeUniV3Test is LiquidityBridgeContext {
    UniV3PoolBuilder builder;

    function setUp() public override {
        super.setUp();
    }

    function setTokens() internal override {
        base = loadToken("WBTC");
        quote = loadToken("USDT");
    }

    function setDex() internal override {
        builder = new UniV3PoolBuilder(base, quote, 500);

        builder.initiateLiquidity(
            larry,
            ud(25_000e18),
            ud(100_000e18),
            ud(23_000e18),
            ud(27_000e18)
        );

        dex = new DexUniV3(address(builder.pool()));
    }
}
