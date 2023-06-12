// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {IMangrove} from "mgv_src/IMangrove.sol";
import {IERC20, MgvLib} from "mgv_src/MgvLib.sol";
import {DexFix} from "../src/DexLogic/DexFix.sol";
import {LiquidityBridge} from "../src/LiquidityBridge.sol";
import {MgvStructs} from "mgv_src/MgvLib.sol";
import {ERC20Normalizer} from "../src/ERC20Normalizer.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";

contract LiquidityBridgeScript is Script {
    IMangrove MGV;
    uint256 DEPLOYER_PK;
    address DEPLOYER;
    IERC20 BASE;
    IERC20 QUOTE;
    ERC20Normalizer N;

    function setUp() public {
        MGV = IMangrove(payable(vm.envAddress("MANGROVE")));
        vm.label(address(MGV), "MGV");
        DEPLOYER_PK = vm.envUint("PRIVATE_KEY");
        DEPLOYER = vm.envAddress("ADMIN_ADDRESS");
        vm.label(DEPLOYER, "DEPLOYER");
        BASE = IERC20(vm.envAddress("WETH"));
        vm.label(address(BASE), "BASE");
        QUOTE = IERC20(vm.envAddress("USDC"));
        vm.label(address(QUOTE), "QUOTE");
        N = new ERC20Normalizer();
    }

    function best_ask() public {
        console2.log("Balance pre deal", DEPLOYER.balance);
        vm.deal(DEPLOYER, 0.1 ether);
        console2.log("Balance post deal", DEPLOYER.balance);

        // vm.startBroadcast(deployerPrivateKey);

        console2.log("Base decimals", BASE.decimals());

        console2.log("Quote decimals", QUOTE.decimals());

        uint best = MGV.best(address(BASE), address(QUOTE));

        MgvStructs.OfferPacked offer = MGV.offers(
            address(BASE),
            address(QUOTE),
            best
        );

        console2.log("Offer wants", offer.wants());
        console2.log("Offer gives", offer.gives());

        console2.log(
            "Best ask price: ",
            ((offer.wants() * 10 ** 12) / offer.gives())
        );

        uint mid = (N.normalize(QUOTE, offer.wants()) /
            N.normalize(BASE, offer.gives()));
        console2.log("Mid price: ", mid);

        console2.log("End script balance", DEPLOYER.balance);
        // vm.stopBroadcast();
    }

    function run() public {
        vm.deal(DEPLOYER, 0.1 ether);

        vm.startBroadcast(DEPLOYER_PK);

        DexFix dex = new DexFix(address(BASE), address(QUOTE));
        dex.setPrice(ud(1831e18));
        console2.log(
            "Dex mid price",
            dex.currentPrice(address(BASE), address(QUOTE)).intoUint256()
        );

        LiquidityBridge lu = new LiquidityBridge(
            MGV,
            BASE,
            QUOTE,
            ud(500e18),
            ud(1005e15),
            address(dex),
            DEPLOYER
        );

        console2.log(
            "Unifier provision pre transfer",
            MGV.balanceOf(address(lu))
        );
        MGV.fund{value: 0.1 ether}(address(lu));
        console2.log(
            "Unifier provision post transfer",
            MGV.balanceOf(address(lu))
        );

        uint bidId;
        uint askId;
        (bidId, askId) = lu.newLiquidityOffers(0, 0);

        console2.log("bidId", bidId);
        console2.log("askId", askId);
    }
}
