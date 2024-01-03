// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import {Script, console2} from "forge-std/Script.sol";
import {ForkFactory} from "src/_test/utils/ForkFactory.sol";
import {IERC20} from "@mgv/src/core/MgvLib.sol";
import {GenericFork} from "@mgv/test/lib/forks/Generic.sol";
import {MgvReader, toOLKey, Market} from "@mgv/src/periphery/MgvReader.sol";
import {MgvLib, OLKey} from "@mgv/src/core/MgvLib.sol";
import {TickLib} from "@mgv/lib/core/TickLib.sol";
import {LiquidityBridge} from "src/LiquidityBridge.sol";
import {IMangrove} from "@mgv/src/IMangrove.sol";
import {MgvReader} from "@mgv/src/periphery/MgvReader.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";

contract BridgeAdminScript is Script {
    GenericFork fork;

    address chief;

    IMangrove mgv;
    MgvReader reader;

    IERC20 base;
    IERC20 quote;
    LiquidityBridge bridge;

     // Defined by the previous things.
    OLKey public  olKeyB; //(base, quote)
    OLKey public  olKeyQ; //(quote, base)

    function setUp() public {
        fork = ForkFactory.getFork();
        fork.setUp();

        mgv = IMangrove(fork.get("Mangrove"));
        reader = MgvReader(fork.get("MgvReader"));

        chief = vm.envAddress("CHIEF");
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

        bridge = LiquidityBridge(payable(vm.envAddress("BRIDGE")));
    }

    function run() public pure {
        console2.log("Please run dedicated command with -s parameter");
    }

    function balances() public view {
        console2.log("Bridge balance", address(bridge).balance);
        console2.log("Bridge base balance", base.balanceOf(address(bridge)));
        console2.log("Bridge quote balance", quote.balanceOf(address(bridge)));

        console2.log("Chief balance", chief.balance);
        console2.log("Chief base balance", base.balanceOf(chief));
        console2.log("Chief quote balance", quote.balanceOf(chief));
    }

    function approveAsk() public {
        vm.startBroadcast(fork.get("TAKER"));
        quote.approve(address(mgv), 200_000000);
    }

    function tradeAsk() public {
        vm.startBroadcast();
        address taker = fork.get("TAKER");
        console2.log("Taker quote balance", quote.balanceOf(taker));
        console2.log("Taker base balance", base.balanceOf(taker));

        mgv.marketOrderByVolume({
            olKey: olKeyB,
            takerWants: 100_000000,
            takerGives: 101_000000,
            fillWants: true
        });
    }

    function activate() public {
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = base;
        tokens[1] = quote;

        vm.startBroadcast();
        bridge.activate(tokens);
    }

    function fund() public {
        vm.startBroadcast();
        mgv.fund{value: 50e18}(address(bridge));
    }

    // fund activate newoffers
    function fano() public {
        vm.startBroadcast();
        // fund
        mgv.fund{value: 50e18}(address(bridge));

        // activate
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = base;
        tokens[1] = quote;

        bridge.activate(tokens);

        // newoffers
        bridge.newLiquidityOffers();

        bridge.retractOffers(true);
    }

    function withdrawAll() public {
        vm.startBroadcast();

        bridge.withdrawBalance();
        bridge.withdrawToken(
            address(base),
            base.balanceOf(address(bridge)),
            chief
        );
        bridge.withdrawToken(
            address(quote),
            quote.balanceOf(address(bridge)),
            chief
        );
    }

    function newOffers() public {
        vm.startBroadcast();
        bridge.newLiquidityOffers();
    }

    function retractOffers() public {
        vm.startBroadcast();
        bridge.retractOffers(true);
    }

    function retractAndWithdraw() public {
        vm.startBroadcast();
        bridge.retractOffers(true);
        bridge.withdrawBalance();
        bridge.withdrawToken(
            address(base),
            base.balanceOf(address(bridge)),
            chief
        );
        bridge.withdrawToken(
            address(quote),
            quote.balanceOf(address(bridge)),
            chief
        );
    }

    function refreshOffers() public {
        vm.startBroadcast();
        bridge.refreshOffers();
    }

    function updateParamAndRefresh() public {
        vm.startBroadcast();
        bridge.setSpreadRatio(ud(10005e14));
        //bridge.setQuoteAmount(ud(100_000e18));
        bridge.refreshOffers();
    }
}
