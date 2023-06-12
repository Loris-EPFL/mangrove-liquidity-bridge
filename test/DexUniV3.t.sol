// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import {TestContext} from "./utils/TestContext.sol";
import {IERC20} from "mgv_src/MgvLib.sol";
import {DexUniV3} from "src/DexLogic/DexUniV3.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {ERC20Normalizer} from "src/ERC20Normalizer.sol";

contract DexUniV3Test is TestContext {
    DexUniV3 dex;
    IERC20 base;
    IERC20 quote;
    address alice = address(1111);

    function setUp() public {}

    function setDex(uint24 fee) public {
        console2.log("DexUniV3Test/setUp/profile", profile);

        address swapRouteur = loadAddress("UNIV3_ROUTER");
        vm.label(swapRouteur, "UniV3-routeur");

        address factory = loadAddress("UNIV3_FACTORY");
        vm.label(factory, "UniV3-factory");

        dex = new DexUniV3(swapRouteur, factory, fee);
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
