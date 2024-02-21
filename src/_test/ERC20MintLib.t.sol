// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "forge-std/StdUtils.sol";
import {Test2} from "@mgv/lib/Test2.sol";
import {ForkFactory} from "./utils/ForkFactory.sol";
import {GenericFork} from "@mgv/test/lib/forks/Generic.sol";
import {IERC20} from "@mgv/src/core/MgvLib.sol";
import {ERC20Normalizer} from "src/ERC20Normalizer.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";

contract ERC20MintLibTest is Test2 {
    GenericFork fork;

    IERC20 public base;
    IERC20[] public tokens;
    address alice;
    address bob;
    ERC20Normalizer N;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("https://polygon-mumbai.g.alchemy.com/v2/cmy55SdtwfrzfFpbN_SSjl9ioQscFnHJ"), 16_791_458);

        address USDT = 0xA02f6adc7926efeBBd59Fd43A84f4E0c0c91e832;
        address WMATIC = 0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889;
        tokens.push(IERC20(USDT));
        tokens.push(IERC20(WMATIC));

        alice = makeAddr("alice");
        bob = makeAddr("bob");

        N = new ERC20Normalizer();
    }

    function testMint() public {
        UD60x18 amount = ud(1e18);
        uint amountDenorm;
        for (uint256 i = 0; i < tokens.length; i++) {
            console2.log("testMint/Iterating on: ", tokens[i].name());
            IERC20 token = tokens[i];
            amountDenorm = N.denormalize(token, amount.unwrap());

            deal(address(token), alice, amountDenorm);
            assertEq(token.balanceOf(alice), amountDenorm);
        }
    }

    function testTransfer() public {
        UD60x18 amount = ud(1e18);
        uint amountDenorm;

        for (uint256 i = 0; i < tokens.length; i++) {
            console2.log("testTransfer/Iterating on: ", tokens[i].name());
            IERC20 token = tokens[i];
            amountDenorm = N.denormalize(token, amount.unwrap());

            deal(address(token), alice, amountDenorm);

            vm.prank(alice);
            token.transfer(bob, amountDenorm);

            assertEq(token.balanceOf(alice), 0);
            assertEq(token.balanceOf(bob), amountDenorm);
        }
    }
}
