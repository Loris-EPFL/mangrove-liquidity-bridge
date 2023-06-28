// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import {MangroveTest} from "mgv_test/lib/MangroveTest.sol";

contract FirstMangroveTest is MangroveTest {
    address larry;
    address taker;

    function setUp() public override {
        options.base.symbol = "WETH";
        options.base.decimals = 18;

        options.quote.symbol = "USDC";
        options.quote.decimals = 6;

        super.setUp();

        taker = freshAddress("maker");
        larry = freshAddress("larry");

        deal(taker, 10 ether);
        deal($(base), taker, cash(base, 10));
        deal($(quote), taker, cash(quote, 10_000));

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
