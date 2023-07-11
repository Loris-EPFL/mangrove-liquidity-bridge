// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import {Script, console2} from "forge-std/Script.sol";
import {ForkFactory} from "src/_test/utils/ForkFactory.sol";
import {IERC20} from "mgv_src/MgvLib.sol";
import {GenericFork} from "mgv_test/lib/forks/Generic.sol";
import {LiquidityBridge} from "src/LiquidityBridge.sol";
import {IMangrove} from "mgv_src/IMangrove.sol";
import {MgvReader} from "mgv_src/periphery/MgvReader.sol";
import {MgvStructs} from "mgv_src/MgvLib.sol";

contract BridgeAdminScript is Script {
    GenericFork fork;

    address chief;

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

        chief = fork.get("CHIEF");
        base = IERC20(fork.get("USDC"));
        quote = IERC20(fork.get("USDT"));

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

        mgv.marketOrder({
            outbound_tkn: address(base),
            inbound_tkn: address(quote),
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
        bridge.newLiquidityOffers(0, 0);
    }

    function retractOffers() public {
        vm.startBroadcast();
        bridge.retractOffers(true);
    }

    function refreshOffers() public {
        vm.startBroadcast();
        bridge.refreshOffers();
    }
}
