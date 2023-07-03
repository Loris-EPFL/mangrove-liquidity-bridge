// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import {Script, console2} from "forge-std/Script.sol";
import {ForkFactory} from "src/_test/utils/ForkFactory.sol";
import {IERC20} from "mgv_src/MgvLib.sol";
import {GenericFork} from "mgv_test/lib/forks/Generic.sol";
import {IMangrove} from "mgv_src/IMangrove.sol";
import {MgvStructs} from "mgv_src/MgvLib.sol";

contract DeploymentContextScript is Script {
    GenericFork fork;

    IMangrove mgv;

    IERC20 public base;
    IERC20 public quote;

    function run() public {
        setUp();
        // mangrove OB exists + output KPIs
        // kpi 1 : density, impact on quoteAmount

        // target dex exists + output KPIs
        // kpi 1 : current midPrice
        // kpi 2 : slippage for quoteAmount
    }

    function setUp() public {
        fork = ForkFactory.getFork(vm);
        fork.setUp();

        base = IERC20(fork.get("WBTC"));
        quote = IERC20(fork.get("USDT"));

        mgv = IMangrove(fork.get("Mangrove"));

        uint best;
        best = mgv.best(address(base), address(quote));

        MgvStructs.OfferPacked offer;
        offer = mgv.offers(address(base), address(quote), best);

        console2.log("Offer wants", offer.wants());
        console2.log("Offer gives", offer.gives());
    }
}
