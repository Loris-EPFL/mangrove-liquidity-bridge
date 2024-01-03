// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import {MangroveTest} from "@mgv/test/lib/MangroveTest.sol";
import {ForkFactory} from "./utils/ForkFactory.sol";
import {GenericFork} from "@mgv/test/lib/forks/Generic.sol";
import {UniV3PoolBuilder} from "./utils/UniV3PoolBuilder.sol";
import {Local} from "@mgv/src/preprocessed/Local.post.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {LiquidityBridge} from "src/LiquidityBridge.sol";
import {MgvReader, toOLKey, Market} from "@mgv/src/periphery/MgvReader.sol";
import {MgvLib, OLKey} from "@mgv/src/core/MgvLib.sol";
import {IERC20} from "@mgv/src/core/MgvLib.sol";
import {IMangrove} from "@mgv/src/IMangrove.sol";
import {IDexLogic} from "src/DexLogic/IDexLogic.sol";
import {DexUniV3} from "src/DexLogic/DexUniV3.sol";

contract LiquidityBridgeDeployedMgvTest is MangroveTest {
    GenericFork fork;

    address larry;
    address taker;

    OLKey public olKeyB; //(base, quote)
    OLKey public olKeyQ;

    UniV3PoolBuilder poolBuilder;
    LiquidityBridge bridge;
    IDexLogic dex;

    function setUp() public override {
        // load context and deployed addresses
        fork = ForkFactory.getFork();
        fork.setUp();

        options.base.symbol = "WETH";
        options.base.decimals = 18;

        options.quote.symbol = "USDC";
        options.quote.decimals = 6;

        olKeyB = toOLKey(Market({
            tkn0: address(base), 
            tkn1: address(quote), 
            tickSpacing: 1
        }));

        olKeyQ = toOLKey(Market({
            tkn0: address(quote), 
            tkn1: address(base), 
            tickSpacing: 1
        }));

        // load mangrove test context
        super.setUp();
        setupMarket(mgv, olKeyB);

        // create users
        taker = freshAddress("maker");
        larry = freshAddress("larry");

        setupDex();
        setupLiquidityBridge();
        // setupMakerLarry();
        setupTaker();
    }

    function setupDex() private {
        poolBuilder = new UniV3PoolBuilder(fork);
        poolBuilder.createPool(base, quote, 500);

        poolBuilder.initiateLiquidity(
            larry,
            ud(1_000e18),
            ud(100_000e18),
            ud(700e18),
            ud(1_300e18)
        );

        dex = new DexUniV3(address(poolBuilder.pool()), address(this));
    }

    function setupLiquidityBridge() private {
        bridge = new LiquidityBridge(
            IMangrove(payable(address(mgv))),
            base,
            quote,
            ud(1000e18),
            ud(1050e15),
            address(dex),
            address(this)
        );
        vm.label(address(bridge), "bridge");

        mgv.fund{value: 10 ether}(address(bridge));
        bridge.newLiquidityOffers();

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = base;
        tokens[1] = quote;
        bridge.activate(tokens);
    }

    /*
    function setupMakerLarry() private {
        deal(larry, 10 ether);
        deal($(base), larry, cash(base, 1000));
        deal($(quote), larry, cash(quote, 1000_000));

        vm.startPrank(larry);
        base.approve(address(mgv), type(uint256).max);
        quote.approve(address(mgv), type(uint256).max);
        /*
        _newOffer(
            OfferArgs({
            olKey: olKeyB, 
            tick: tick, 
            gives: notNormGiveAmount, 
            gasreq: 400000, 
            gasprice: 0, 
            fund: msg.value, 
            noRevert: false
            })
        );
      

        mgv.newOffer{value: 1 ether}({
            outbound_tkn: $(base),
            inbound_tkn: $(quote),
            wants: cash(quote, 1201),
            gives: cash(base, 1),
            gasreq: 50_000,
            gasprice: 0,
            pivotId: 0
        });
        mgv.newOffer({
            outbound_tkn: $(quote),
            inbound_tkn: $(base),
            wants: cash(base, 1),
            gives: cash(quote, 800),
            gasreq: 50_000,
            gasprice: 0,
            pivotId: 0
        });
        vm.stopPrank();
    }
    */
    function setupTaker() private {
        deal(taker, 10 ether);
        deal($(base), taker, cash(base, 10));
        deal($(quote), taker, cash(quote, 10_000));
    }

    function testInitMangroveOB() public {
        printOfferList(olKeyB);
        printOfferList(olKeyQ);
        succeed();
    }

    //https://docs.mangrove.exchange/contracts/technical-references/taking-and-making-offers/taker-order/
    function testTakeAsk() public {
        printOfferList(olKeyB);

        vm.startPrank(taker);
        quote.approve(address(mgv), type(uint256).max);
        /*
        (uint takerGot, uint takerGave, , ) = mgv.marketOrder(
            $(base),
            $(quote),
            cash(base, 5, 2), // 0.5
            cash(quote, 1000),
            true
        );*/

        (uint takerGot, uint takerGave, , ) = mgv.marketOrderByVolume(olKeyB, cash(base, 5, 2), cash(quote, 1000), true);
        vm.stopPrank();

        console2.log("takerGot", takerGot);
        console2.log("takerGave", takerGave);
        console2.log("----Ask Side---");
        printOfferList(olKeyB);
        console2.log("----Bid Side-----");
        printOfferList(olKeyQ);

    }

    function testTakeBid() public {
        printOfferList(olKeyQ);

        vm.startPrank(taker);
        base.approve(address(mgv), cash(base, 1));
        (uint takerGot, uint takerGave, , ) = mgv.marketOrderByVolume(olKeyQ, cash(quote, 950), cash(base, 1), false);
        /*
        (uint takerGot, uint takerGave, , ) = mgv.marketOrder(
            $(quote),
            $(base),
            cash(quote, 950),
            cash(base, 1),
            false
        );
        */
        vm.stopPrank();

        console2.log("takerGot", takerGot);
        console2.log("takerGave", takerGave);
        printOfferList(olKeyQ);
    }
}
