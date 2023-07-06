// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import {Test2} from "mgv_lib/Test2.sol";
import {ForkFactory} from "./ForkFactory.sol";
import {GenericFork} from "mgv_test/lib/forks/Generic.sol";
import {IERC20} from "mgv_src/MgvLib.sol";
import {ERC20Normalizer} from "src/ERC20Normalizer.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {LiquidityBridge} from "src/LiquidityBridge.sol";
import {IMangrove} from "mgv_src/IMangrove.sol";
import {MgvStructs} from "mgv_src/MgvLib.sol";
import {IDexLogic} from "src/DexLogic/IDexLogic.sol";
import {DexFix} from "src/DexLogic/DexFix.sol";

abstract contract LiquidityBridgeContext is Test2 {
    GenericFork fork;
    IMangrove mgv;

    IERC20 base;
    IERC20 quote;

    LiquidityBridge bridge;
    IDexLogic dex;

    ERC20Normalizer N;

    address alice;
    address larry;

    fallback() external payable {}

    receive() external payable {}

    function setUp() public virtual {
        N = new ERC20Normalizer();

        fork = ForkFactory.getFork();
        fork.setUp();

        alice = freshAddress("alice");
        larry = freshAddress("larry");

        setTokens();
        setMangrove();

        setDex();
    }

    function setMangrove() internal virtual {
        mgv = IMangrove(fork.get("Mangrove"));
        vm.label(address(mgv), "mgv");
    }

    function setTokens() internal virtual;

    function setDex() internal virtual;

    function testMintTokens() public {
        uint amountDenorm = N.denormalize(base, 1e18);

        deal(address(base), address(this), amountDenorm);
        deal(address(quote), address(this), amountDenorm);

        assertEq(base.balanceOf(address(this)), amountDenorm);
        assertEq(quote.balanceOf(address(this)), amountDenorm);
    }

    function testGetDexCurrentPrice() public {
        UD60x18 price = dex.currentPrice(address(base), address(quote));
        assertGt(price.unwrap(), 0);
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
            offer.wants(),
            N.denormalize(IERC20(token_in), offer_wants.unwrap())
        );
        assertEq(
            offer.gives(),
            N.denormalize(IERC20(token_out), offer_gives.unwrap())
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
        UD60x18 midPrice = dex.currentPrice(address(base), address(quote));
        UD60x18 bridgedQuoteAmount = ud(1000e18);
        UD60x18 spreadRatio = ud(1010e15);

        uint askId;
        uint bidId;

        (askId, bidId) = setLiquidityBridge(bridgedQuoteAmount, spreadRatio);

        spreadRatio = spreadRatio.pow(ud(2e18));
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
        UD60x18 bridgedQuoteAmount = ud(1000e18);
        UD60x18 spreadGeo = ud(1010e15);

        uint askId;

        (askId, ) = setLiquidityBridge(bridgedQuoteAmount, spreadGeo);

        // mint quote token for alice

        deal(
            address(quote),
            alice,
            N.denormalize(quote, bridgedQuoteAmount.unwrap())
        );

        // mint base token for DexFix
        deal(
            address(base),
            address(dex),
            N.denormalize(
                base,
                bridgedQuoteAmount
                    .div(dex.currentPrice(address(base), address(quote)))
                    .mul(ud(2e18))
                    .unwrap()
            )
        );

        // [[offerId, minTakerWants, maxTakerGives, gasReqPermitted]]
        uint[4][] memory snipeParams = new uint[4][](1);
        snipeParams[0] = [askId, 0, type(uint96).max, type(uint).max];

        // allow mgv to spend quote tokens for alice
        vm.prank(alice);
        quote.approve(address(mgv), type(uint).max);

        MgvStructs.OfferPacked askOffer;
        askOffer = mgv.offers(address(base), address(quote), askId);
        console2.log(
            "This base balance before snipe:",
            base.balanceOf(address(this))
        );

        // https://docs.mangrove.exchange/contracts/technical-references/taking-and-making-offers/taker-order/#inputs-1
        vm.prank(alice);
        (uint successes, uint takerGot, uint takerGave, uint bounty, uint fee) = mgv
            .snipes(
                address(base),
                address(quote),
                snipeParams,
                false // fillwants
            );

        console2.log(
            "This base balance after snipe:",
            base.balanceOf(address(this))
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
        UD60x18 bridgedQuoteAmount = ud(1000e18);
        UD60x18 spreadGeo = ud(1010e15);

        uint askId;

        (askId, ) = setLiquidityBridge(bridgedQuoteAmount, spreadGeo);

        // mint quote token for alice
        deal(
            address(quote),
            alice,
            N.denormalize(quote, bridgedQuoteAmount.unwrap())
        );

        // mint base token for DexFix
        deal(
            address(base),
            address(dex),
            N.denormalize(
                base,
                bridgedQuoteAmount
                    .div(dex.currentPrice(address(base), address(quote)))
                    .mul(ud(2e18))
                    .unwrap()
            )
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
        UD60x18 bridgedQuoteAmount = ud(10000e18);
        UD60x18 spreadGeo = ud(1010e15);

        uint bidId;

        (, bidId) = setLiquidityBridge(bridgedQuoteAmount, spreadGeo);

        // mint base token for alice, with margin (x)
        deal(
            address(base),
            alice,
            N.denormalize(
                base,
                bridgedQuoteAmount
                    .div(dex.currentPrice(address(base), address(quote)))
                    .mul(ud(2e18))
                    .unwrap()
            )
        );
        console2.log("alice eth balance", alice.balance);

        // mint quote token for DexFix, with margin (x2)
        deal(
            address(quote),
            address(dex),
            N.denormalize(quote, bridgedQuoteAmount.mul(ud(2e18)).unwrap())
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

        assertEq(successes, 1);
        assertEq(takerGave, bidOffer.wants());
        assertEq(takerGot, bidOffer.gives());
        assertEq(bounty, 0);
        assertEq(fee, 0);
        assertEq(base.balanceOf(address(bridge)), 0);
        assertEq(quote.balanceOf(address(bridge)), 0);
    }
}
