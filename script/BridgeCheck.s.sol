// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import {Test2} from "@mgv/lib/Test2.sol";
import {Script, console2} from "forge-std/Script.sol";
import {ForkFactory} from "src/_test/utils/ForkFactory.sol";
import {IERC20} from "@mgv/src/core/MgvLib.sol";
import {GenericFork} from "@mgv/test/lib/forks/Generic.sol";
import {MangroveTest} from "@mgv/test/lib/MangroveTest.sol";
import {LiquidityBridge} from "src/LiquidityBridge.sol";
import {IMangrove} from "@mgv/src/IMangrove.sol";
import {AbstractMangrove} from "@mgv/src/AbstractMangrove.sol"; //TOFIX: DELETE ABSTRACTMANGROVE
import {MgvReader} from "@mgv/src/periphery/MgvReader.sol";
import {MgvStructs} from "@mgv/src/core/MgvLib.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";

contract MgvTestViewer is MangroveTest {
    function setUp(AbstractMangrove mgv_, MgvReader reader_) public {
        mgv = mgv_;
        reader = reader_;
    }

    function printOB(address base, address quote) public view {
        super.printOrderBook(base, quote);
    }
}

contract BridgeCheckScript is Test2 {
    GenericFork fork;
    IMangrove mgv;
    MgvReader reader;
    IERC20 base;
    IERC20 quote;
    LiquidityBridge bridge;

    function setUp() public {
        fork = ForkFactory.getFork();
        fork.setUp();

        mgv = IMangrove(fork.get("Mangrove"));
        reader = MgvReader(fork.get("MgvReader"));

        base = IERC20(fork.get("USDC"));
        quote = IERC20(fork.get("USDT"));
    }

    function run() public pure {
        console2.log("Please run dedicated command with -s parameter");
    }

    // forge script BridgeCheckScript --tc BridgeCheckScript -f $ANVIL_URL -vv -s "displayOB()"
    function displayOB() public {
        MgvTestViewer mgvTest = new MgvTestViewer();
        mgvTest.setUp(AbstractMangrove(payable(address(mgv))), reader);

        mgvTest.printOB(address(base), address(quote));

        mgvTest.printOB(address(quote), address(base));
    }

    function snipeOffer(IERC20 ofr_tkn, IERC20 req_tkn, uint offerId) public {
        MgvStructs.OfferPacked offer = mgv.offers(
            address(ofr_tkn),
            address(req_tkn),
            offerId
        );

        console2.log("Offer wants", offer.wants());
        console2.log("Offer gives", offer.gives());

        uint aow = offer.wants();
        deal(address(req_tkn), address(this), aow * 4);
        req_tkn.approve(address(mgv), type(uint).max);

        // [[offerId, minTakerWants, maxTakerGives, gasReqPermitted]]
        uint[4][] memory snipeParams = new uint[4][](1);
        snipeParams[0] = [offerId, 0, 0, type(uint).max];

        uint[] memory takerWants = dynamic([0, aow / 2, aow]);

        uint success;
        for (uint i = 0; i < takerWants.length; i++) {
            console2.log("Snipe taker wants", takerWants[i]);

            snipeParams[0][2] = takerWants[i];

            (success, , , , ) = mgv.snipes(
                address(ofr_tkn),
                address(req_tkn),
                snipeParams,
                false
            );
            console2.log("Snipe success", success);
        }
    }

    function snipeAsk() public {
        snipeOffer(base, quote, 234);
    }

    function snipeBid() public {
        snipeOffer(quote, base, 234);
    }

    function snipeOffers() public {
        console2.log("==> Sniping Ask...");
        snipeAsk();
        console2.log("==> Sniping Bid...");
        snipeBid();
    }
}
