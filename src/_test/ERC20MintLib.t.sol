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
        fork = ForkFactory.getFork();
        fork.setUp();

        
        tokens.push(IERC20(fork.get("USDT")));
        tokens.push(IERC20(fork.get("WMATIC")));

        alice = freshAddress("alice");
        bob = freshAddress("bob");

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
