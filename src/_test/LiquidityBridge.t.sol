// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import {TestContext} from "./utils/TestContext.sol";

import {IERC20} from "mgv_src/MgvLib.sol";
import {ERC20Normalizer} from "src/ERC20Normalizer.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {LiquidityBridge} from "src/LiquidityBridge.sol";
import {IMangrove} from "mgv_src/IMangrove.sol";
import {MgvStructs} from "mgv_src/MgvLib.sol";
import {IDexLogic} from "src/DexLogic/IDexLogic.sol";
import {DexFix} from "src/DexLogic/DexFix.sol";

contract LiquidityBridgeTest is TestContext {
    IMangrove mgv;
    LiquidityBridge bridge;

    IERC20 base;
    IERC20 quote;

    address alice = address(1111);
    address bob = address(2222);
    address charlie = address(3333);

    IDexLogic dex;

    fallback() external payable {}

    receive() external payable {}

    function setUp() public override {
        super.setUp();
        mgv = IMangrove(payable(loadAddress("MANGROVE")));
        base = loadToken("WMATIC");
        quote = loadToken("USDT");

        vm.label(address(mgv), "mgv");
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(address(base), "base");
        vm.label(address(quote), "quote");

        vm.label(address(this), "BridgeTest");
    }

    // testing the capacity to mint tokens from config
    function testMintTokens() public {
        uint amountDenorm = N.denormalize(base, 1e18);

        deal(address(base), address(this), amountDenorm);
        deal(address(quote), address(this), amountDenorm);

        assertEq(base.balanceOf(address(this)), amountDenorm);
        assertEq(quote.balanceOf(address(this)), amountDenorm);
    }

    function setDexFix() public {
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

    function getDexCurrentPrice() public view returns (UD60x18) {
        return dex.currentPrice(address(base), address(quote));
    }

    function setLiquidityBridge(
        UD60x18 bridgedQuoteAmount,
        UD60x18 spreadRatio
    ) public returns (uint askId, uint bidId) {
        bridge = new LiquidityBridge(
            mgv,
            base,
            quote,
            bridgedQuoteAmount,
            spreadRatio,
            address(dex),
            address(this)
        );
        vm.label(address(bridge), "bridge");

        mgv.fund{value: 0.1 ether}(address(bridge));
        (askId, bidId) = bridge.newLiquidityOffers(0, 0);

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = base;
        tokens[1] = quote;
        bridge.activate(tokens);
    }

    function getAskOffer(
        uint askId
    ) public view returns (MgvStructs.OfferPacked) {
        return mgv.offers(address(base), address(quote), askId);
    }

    function getBidOffer(
        uint bidId
    ) public view returns (MgvStructs.OfferPacked) {
        return mgv.offers(address(quote), address(base), bidId);
    }

    function assertOffer(
        address token_in,
        UD60x18 offer_wants,
        address token_out,
        UD60x18 offer_gives,
        MgvStructs.OfferPacked offer
    ) private {
        assertEq(
            N.normalize(IERC20(token_in), offer.wants()),
            offer_wants.unwrap()
        );
        assertEq(
            N.normalize(IERC20(token_out), offer.gives()),
            offer_gives.unwrap()
        );
    }

    function assertAskOffer(
        UD60x18 offer_wants,
        UD60x18 offer_gives,
        uint askId
    ) public {
        MgvStructs.OfferPacked offer = getAskOffer(askId);

        assertOffer(
            address(quote),
            offer_wants,
            address(base),
            offer_gives,
            offer
        );
    }

    function assertBidOffer(
        UD60x18 offer_wants,
        UD60x18 offer_gives,
        uint bidId
    ) public {
        MgvStructs.OfferPacked offer = getBidOffer(bidId);

        assertOffer(
            address(base),
            offer_wants,
            address(quote),
            offer_gives,
            offer
        );
    }

    function testNewOffers() public {
        setDexFix();
        UD60x18 midPrice = dex.currentPrice(address(base), address(quote));
        UD60x18 bridgedQuoteAmount = ud(1000e18);
        UD60x18 spreadRatio = ud(1010e15);

        uint askId;
        uint bidId;

        (askId, bidId) = setLiquidityBridge(bridgedQuoteAmount, spreadRatio);

        // testing ask offer
        assertAskOffer(
            bridgedQuoteAmount,
            bridgedQuoteAmount.div(midPrice).div(spreadRatio),
            askId
        );

        // testing bid offer
        assertBidOffer(
            bridgedQuoteAmount.div(midPrice).mul(spreadRatio),
            bridgedQuoteAmount,
            bidId
        );
    }

    function testUpdateQuoteAmount() public {
        setDexFix();
        UD60x18 midPrice = dex.currentPrice(address(base), address(quote));
        UD60x18 bridgedQuoteAmount = ud(1000e18);
        UD60x18 spreadRatio = ud(1010e15);

        uint askId;
        uint bidId;

        (askId, bidId) = setLiquidityBridge(bridgedQuoteAmount, spreadRatio);

        bridgedQuoteAmount = bridgedQuoteAmount.mul(ud(2e18));
        bridge.setQuoteAmount(bridgedQuoteAmount);
        bridge.refreshOffers();

        // testing ask offer
        assertAskOffer(
            bridgedQuoteAmount,
            bridgedQuoteAmount.div(midPrice).div(spreadRatio),
            askId
        );

        // testing bid offer
        assertBidOffer(
            bridgedQuoteAmount.div(midPrice).mul(spreadRatio),
            bridgedQuoteAmount,
            bidId
        );
    }

    function testUpdateSpreadRatio() public {
        setDexFix();
        UD60x18 midPrice = dex.currentPrice(address(base), address(quote));
        UD60x18 bridgedQuoteAmount = ud(1000e18);
        UD60x18 spreadRatio = ud(1010e15);

        uint askId;
        uint bidId;

        (askId, bidId) = setLiquidityBridge(bridgedQuoteAmount, spreadRatio);

        spreadRatio = spreadRatio.mul(ud(2e18));
        bridge.setSpreadRatio(spreadRatio);
        bridge.refreshOffers();

        // testing ask offer
        assertAskOffer(
            bridgedQuoteAmount,
            bridgedQuoteAmount.div(midPrice).div(spreadRatio),
            askId
        );

        // testing bid offer
        assertBidOffer(
            bridgedQuoteAmount.div(midPrice).mul(spreadRatio),
            bridgedQuoteAmount,
            bidId
        );
    }

    function testRetractOffers() public {
        setDexFix();
        UD60x18 bridgedQuoteAmount = ud(1000e18);
        UD60x18 spreadRatio = ud(1010e15);

        uint askId;
        uint bidId;

        (askId, bidId) = setLiquidityBridge(bridgedQuoteAmount, spreadRatio);
        bridge.retractOffers(true);

        assertEq(getAskOffer(askId).gives(), 0);
        assertEq(getBidOffer(bidId).gives(), 0);
    }

    function testSnipeAskGoodPrice() public {
        setDexFix();

        UD60x18 bridgedQuoteAmount = ud(1000e18);
        UD60x18 spreadGeo = ud(1010e15);

        uint askId;

        (askId, ) = setLiquidityBridge(bridgedQuoteAmount, spreadGeo);

        // mint quote token for alice
        dealNorm(quote, alice, bridgedQuoteAmount);

        // mint base token for DexFix
        dealNorm(
            base,
            address(dex),
            bridgedQuoteAmount
                .div(dex.currentPrice(address(base), address(quote)))
                .mul(ud(2e18))
        );

        // [[offerId, minTakerWants, maxTakerGives, gasReqPermitted]]
        uint[4][] memory snipeParams = new uint[4][](1);
        snipeParams[0] = [askId, 0, type(uint96).max, type(uint).max];

        // allow mgv to spend quote tokens for alice
        vm.prank(alice);
        quote.approve(address(mgv), type(uint).max);

        MgvStructs.OfferPacked askOffer;
        askOffer = mgv.offers(address(base), address(quote), askId);

        console2.log("Alice ETH balance", alice.balance);

        // https://docs.mangrove.exchange/contracts/technical-references/taking-and-making-offers/taker-order/#inputs-1
        vm.prank(alice);
        (uint successes, uint takerGot, uint takerGave, uint bounty, uint fee) = mgv
            .snipes(
                address(base),
                address(quote),
                snipeParams,
                false // fillwants
            );
        assertEq(successes, 1);
        assertEq(takerGave, askOffer.wants());
        assertEq(takerGot, askOffer.gives());
        assertEq(bounty, 0);
        assertEq(fee, 0);
        assertEq(base.balanceOf(address(bridge)), 0);
        assertEq(quote.balanceOf(address(bridge)), 0);
    }

    function testMultipleSnipeAskGoodPrice() public {
        setDexFix();

        UD60x18 bridgedQuoteAmount = ud(1000e18);
        UD60x18 spreadGeo = ud(1010e15);

        uint askId;

        (askId, ) = setLiquidityBridge(bridgedQuoteAmount, spreadGeo);

        // mint quote token for alice
        dealNorm(quote, alice, bridgedQuoteAmount);

        // mint base token for DexFix
        dealNorm(
            base,
            address(dex),
            bridgedQuoteAmount
                .div(dex.currentPrice(address(base), address(quote)))
                .mul(ud(2e18))
        );

        // [[offerId, minTakerWants, maxTakerGives, gasReqPermitted]]
        uint[4][] memory snipeParams = new uint[4][](1);
        uint snipeQuoteAmount = N.denormalize(
            quote,
            bridgedQuoteAmount.div(ud(3e18)).unwrap()
        );
        snipeParams[0] = [askId, 0, snipeQuoteAmount, type(uint).max];

        // allow mgv to spend quote tokens for alice
        vm.prank(alice);
        quote.approve(address(mgv), type(uint).max);

        MgvStructs.OfferPacked askOffer;

        for (uint i = 0; i < 2; i++) {
            console2.log("Entering loop round", i);

            askOffer = mgv.offers(address(base), address(quote), askId);

            console2.log("Alice ETH balance", alice.balance);

            // https://docs.mangrove.exchange/contracts/technical-references/taking-and-making-offers/taker-order/#inputs-1
            vm.prank(alice);
            (uint successes, , , uint bounty, uint fee) = mgv.snipes(
                address(base),
                address(quote),
                snipeParams,
                false // fillwants
            );

            assertEq(successes, 1);
            assertEq(bounty, 0);
            assertEq(fee, 0);
            assertEq(base.balanceOf(address(bridge)), 0);
            assertEq(quote.balanceOf(address(bridge)), 0);
        }
    }

    function testSnipeBidGoodPrice() public {
        setDexFix();

        UD60x18 bridgedQuoteAmount = ud(10000e18);
        UD60x18 spreadGeo = ud(1010e15);

        uint bidId;

        (, bidId) = setLiquidityBridge(bridgedQuoteAmount, spreadGeo);

        // mint base token for alice, with margin (x)
        dealNorm(
            base,
            alice,
            bridgedQuoteAmount
                .div(dex.currentPrice(address(base), address(quote)))
                .mul(ud(2e18))
        );
        console2.log("alice base balance", balanceNorm(base, alice) / 10 ** 18);
        console2.log(
            "alice quote balance",
            balanceNorm(quote, alice) / 10 ** 18
        );
        console2.log("alice eth balance", alice.balance);

        // mint quote token for DexFix, with margin (x2)
        dealNorm(quote, address(dex), bridgedQuoteAmount.mul(ud(2e18)));
        console2.log(
            "dex quote balance",
            balanceNorm(quote, address(dex)) / 10 ** 18
        );

        // allow mgv to spend quote tokens for alice
        vm.prank(alice);
        base.approve(address(mgv), type(uint).max);

        MgvStructs.OfferPacked bidOffer;
        bidOffer = mgv.offers(address(quote), address(base), bidId);

        // [[offerId, minTakerWants, maxTakerGives, gasReqPermitted]]
        uint[4][] memory snipeParams = new uint[4][](1);
        snipeParams[0] = [bidId, 0, type(uint96).max, type(uint).max];

        // https://docs.mangrove.exchange/contracts/technical-references/taking-and-making-offers/taker-order/#inputs-1
        vm.prank(alice);
        (uint successes, uint takerGot, uint takerGave, uint bounty, uint fee) = mgv
            .snipes(
                address(quote),
                address(base),
                snipeParams,
                false // fillwants
            );
        console2.log("successes", successes);
        console2.log("takerGot", takerGot);
        console2.log("takerGave", takerGave);
        console2.log("bounty", bounty);
        console2.log("fee", fee);
        console2.log("alice base balance", balanceNorm(base, alice) / 10 ** 18);
        console2.log(
            "alice quote balance",
            balanceNorm(quote, alice) / 10 ** 18
        );
        console2.log(
            "dex base balance",
            balanceNorm(base, address(dex)) / 10 ** 18
        );
        console2.log(
            "dex quote balance",
            balanceNorm(quote, address(dex)) / 10 ** 18
        );
        console2.log(
            "bridge quote balance",
            balanceNorm(quote, address(bridge)) / 10 ** 18
        );
        console2.log("alice eth balance", alice.balance);

        assertEq(successes, 1);
        assertEq(takerGave, bidOffer.wants());
        assertEq(takerGot, bidOffer.gives());
        assertEq(bounty, 0);
        assertEq(fee, 0);
        assertEq(base.balanceOf(address(bridge)), 0);
        assertEq(quote.balanceOf(address(bridge)), 0);
    }

    function testSnipeAskBadPrice() public {
        setDexFix();
        UD60x18 midPriceInit = getDexCurrentPrice();
        UD60x18 bridgedQuoteAmount = ud(1000e18);
        UD60x18 spreadGeo = ud(1010e15);

        uint askId;

        (askId, ) = setLiquidityBridge(bridgedQuoteAmount, spreadGeo);

        // mint quote token for alice
        dealNorm(quote, alice, bridgedQuoteAmount);

        // mint base token for DexFix, with margin (x2)
        dealNorm(
            base,
            address(dex),
            bridgedQuoteAmount.div(midPriceInit).mul(ud(2e18))
        );

        // [[offerId, minTakerWants, maxTakerGives, gasReqPermitted]]
        uint[4][] memory snipeParams = new uint[4][](1);
        snipeParams[0] = [askId, 0, type(uint96).max, type(uint).max];

        // allow mgv to spend quote tokens for alice
        vm.prank(alice);
        quote.approve(address(mgv), type(uint).max);

        MgvStructs.OfferPacked askOffer;
        askOffer = mgv.offers(address(base), address(quote), askId);
        console2.log("askOffer.wants()", askOffer.wants());
        console2.log("askOffer.gives()", askOffer.gives());

        // double increase of midPrice
        DexFix(address(dex)).setPrice(
            midPriceInit.mul(spreadGeo).mul(spreadGeo)
        );

        vm.prank(alice);
        (uint successes, uint takerGot, uint takerGave, uint bounty, uint fee) = mgv
            .snipes(
                address(base),
                address(quote),
                snipeParams,
                false // fillwants
            );

        assertEq(successes, 0);
        assertEq(takerGave, 0);
        assertEq(takerGot, 0);
        assertGt(bounty, 0);

        askOffer = mgv.offers(address(base), address(quote), askId);
        console2.log("askOffer.wants()", askOffer.wants());
        console2.log("askOffer.gives()", askOffer.gives());
    }
}
