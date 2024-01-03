// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import {Test2} from "@mgv/lib/Test2.sol";
import {Script, console2} from "forge-std/Script.sol";
import {ForkFactory} from "src/_test/utils/ForkFactory.sol";
import {IERC20} from "@mgv/src/core/MgvLib.sol";
import {GenericFork} from "@mgv/test/lib/forks/Generic.sol";
import {MangroveTest} from "@mgv/test/lib/MangroveTest.sol";
import {OLKey} from "@mgv/src/core/MgvLib.sol";
import {MgvReader, toOLKey, Market} from "@mgv/src/periphery/MgvReader.sol";
import {LiquidityBridge} from "src/LiquidityBridge.sol";
import {IMangrove} from "@mgv/src/IMangrove.sol";
import {MgvReader} from "@mgv/src/periphery/MgvReader.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";

contract MgvTestViewer is MangroveTest {
    function setUp(IMangrove mgv_, MgvReader reader_) public {
        mgv = mgv_;
        reader = reader_;
        /*
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
        */
    }

    function printOB(OLKey memory olKey) public view {
        super.printOfferList(olKey);
    }
}

contract BridgeCheckScript is Test2 {
    GenericFork fork;
    IMangrove mgv;
    MgvReader reader;
    IERC20 base;
    IERC20 quote;
    LiquidityBridge bridge;
    OLKey olKeyB;
    OLKey olKeyQ;

    function setUp() public {
        fork = ForkFactory.getFork();
        fork.setUp();

        mgv = IMangrove(fork.get("Mangrove"));
        reader = MgvReader(fork.get("MgvReader"));

        base = IERC20(fork.get("USDC"));
        quote = IERC20(fork.get("USDT"));

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
    }

    function run() public pure {
        console2.log("Please run dedicated command with -s parameter");
    }

    // forge script BridgeCheckScript --tc BridgeCheckScript -f $ANVIL_URL -vv -s "displayOB()"
    function displayOB() public {
        MgvTestViewer mgvTest = new MgvTestViewer();
        mgvTest.setUp(IMangrove(payable(address(mgv))), reader);

        // mgvTest.printOB(olKeyB);

        // mgvTest.printOB(olKeyQ);
    }
}
