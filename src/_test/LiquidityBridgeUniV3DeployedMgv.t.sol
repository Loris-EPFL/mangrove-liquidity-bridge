// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import {MangroveTest} from "@mgv/test/lib/MangroveTest.sol";
import {LiquidityBridgeUniV3Test} from "./LiquidityBridgeUniV3.t.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {MgvStructs} from "@mgv/src/core/MgvLib.sol";
import {UniV3PoolBuilder} from "./utils/UniV3PoolBuilder.sol";
import {DexUniV3} from "src/DexLogic/DexUniV3.sol";
import {IERC20} from "@mgv/src/core/MgvLib.sol";
import {IMangrove} from "@mgv/src/IMangrove.sol";

contract MangroveTest2 is MangroveTest {
    function setDensity(uint8 density) public {
        options.density = density;
    }
}

contract LiquidityBridgeUniV3DeployedMgvTest is LiquidityBridgeUniV3Test {
    MangroveTest2 mgvTester;

    function setUp() public override {
        super.setUp();
    }

    function setMangrove() internal override {
        mgvTester = new MangroveTest2();
        mgvTester.setDensity(5);
        address mgvAddress = address(mgvTester.setupMangrove(base, quote));
        mgv = IMangrove(payable(mgvAddress));
    }
}
