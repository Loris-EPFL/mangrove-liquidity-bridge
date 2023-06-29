// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import {MangroveTest} from "mgv_test/lib/MangroveTest.sol";
import {ForkFactory} from "./utils/ForkFactory.sol";
import {GenericFork} from "mgv_test/lib/forks/Generic.sol";
import {UniV3PoolBuilder} from "./utils/UniV3PoolBuilder.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {LiquidityBridge} from "src/LiquidityBridge.sol";
import {IERC20} from "mgv_src/MgvLib.sol";
import {IMangrove} from "mgv_src/IMangrove.sol";
import {IDexLogic} from "src/DexLogic/IDexLogic.sol";
import {DexUniV3} from "src/DexLogic/DexUniV3.sol";

contract FirstMangroveTest is MangroveTest {
    GenericFork fork;

    address larry;
    address taker;

    UniV3PoolBuilder poolBuilder;
    LiquidityBridge bridge;
    IDexLogic dex;

    function setUp() public override {
        // load context and deployed addresses
        fork = ForkFactory.getFork(vm);
        fork.setUp();

        options.base.symbol = "WETH";
        options.base.decimals = 18;

        options.quote.symbol = "USDC";
        options.quote.decimals = 6;

        // load mangrove test context
        super.setUp();
        setupMarket(base, quote);

        // create users
        taker = freshAddress("maker");
        larry = freshAddress("larry");

        setupDex();
        setupLiquidityBridge();
        setupMakerLarry();
        setupTaker();
    }

    function setupDex() private {
        poolBuilder = new UniV3PoolBuilder(fork);
        poolBuilder.createPool(base, quote, 3000);

        poolBuilder.initiateLiquidity(
            larry,
            ud(25_000e18),
            ud(100_000e18),
            ud(23_000e18),
            ud(27_000e18)
        );

        dex = new DexUniV3(address(poolBuilder.pool()));
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

        mgv.fund{value: 0.1 ether}(address(bridge));
        bridge.newLiquidityOffers(0, 0);

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = base;
        tokens[1] = quote;
        bridge.activate(tokens);
    }

    function setupMakerLarry() private {
        deal(larry, 10 ether);
        deal($(base), larry, cash(base, 1000));
        deal($(quote), larry, cash(quote, 1000_000));

        vm.startPrank(larry);
        base.approve(address(mgv), type(uint256).max);
        quote.approve(address(mgv), type(uint256).max);

        mgv.newOffer{value: 1 ether}({
            outbound_tkn: $(base),
            inbound_tkn: $(quote),
            wants: cash(quote, 2100),
            gives: cash(base, 2),
            gasreq: 50_000,
            gasprice: 0,
            pivotId: 0
        });
        mgv.newOffer({
            outbound_tkn: $(quote),
            inbound_tkn: $(base),
            wants: cash(base, 1),
            gives: cash(quote, 950),
            gasreq: 50_000,
            gasprice: 0,
            pivotId: 0
        });
        vm.stopPrank();
    }

    function setupTaker() private {
        deal(taker, 10 ether);
        deal($(base), taker, cash(base, 10));
        deal($(quote), taker, cash(quote, 10_000));
    }

    function testInitMangroveOB() public {
        printOrderBook($(base), $(quote));
        printOrderBook($(quote), $(base));
    }

    //https://docs.mangrove.exchange/contracts/technical-references/taking-and-making-offers/taker-order/
    function testTakeAsk() public {
        vm.startPrank(taker);
        quote.approve(address(mgv), cash(quote, 1060));
        (uint takerGot, uint takerGave, , ) = mgv.marketOrder(
            $(base),
            $(quote),
            cash(base, 1),
            cash(quote, 1060),
            true
        );
        vm.stopPrank();

        console2.log("takerGot", takerGot);
        console2.log("takerGave", takerGave);
        printOrderBook($(base), $(quote));
    }

    function testTakeBid() public {
        vm.startPrank(taker);
        base.approve(address(mgv), cash(base, 1));
        (uint takerGot, uint takerGave, , ) = mgv.marketOrder(
            $(quote),
            $(base),
            cash(quote, 950),
            cash(base, 1),
            false
        );
        vm.stopPrank();

        console2.log("takerGot", takerGot);
        console2.log("takerGave", takerGave);
        printOrderBook($(quote), $(base));
    }
}
