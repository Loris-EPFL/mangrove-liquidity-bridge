// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import {LiquidityBridgeContext} from "./utils/LiquidityBridgeContext.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {MgvStructs} from "@mgv/src/core/MgvLib.sol";
import {DexFix} from "src/DexLogic/DexFix.sol";
import {IERC20} from "@mgv/src/core/MgvLib.sol";

contract LiquidityBridgeFixTest is LiquidityBridgeContext {
    function setUp() public override {
        super.setUp();
    }

    function setTokens() internal override {
        base = IERC20(fork.get("WBTC"));
        quote = IERC20(fork.get("USDT"));
    }

    function setDex() internal override {
        UD60x18 best_ask;
        UD60x18 best_bid;

        uint best;
        MgvStructs.OfferPacked offer;

        best = mgv.best(address(base), address(quote));
        offer = mgv.offers(address(base), address(quote), best);

        best_ask = ud(N.normalize(quote, offer.wants())).div(
            ud(N.normalize(base, offer.gives()))
        );
        console2.log("best_ask", best_ask.unwrap());

        best = mgv.best(address(quote), address(base));
        offer = mgv.offers(address(quote), address(base), best);
        best_bid = ud(N.normalize(quote, offer.gives())).div(
            ud(N.normalize(base, offer.wants()))
        );
        console2.log("best_bid", best_bid.unwrap());

        UD60x18 mid = best_ask.avg(best_bid);
        console2.log("mid", mid.unwrap());

        DexFix dexfix;
        dexfix = new DexFix(address(base), address(quote));
        dexfix.setPrice(mid);
        dex = dexfix;
        vm.label(address(dex), "dex (fix)");
    }
}
