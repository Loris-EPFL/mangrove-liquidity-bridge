// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "forge-std/StdUtils.sol";
import {IERC20} from "mgv_src/MgvLib.sol";
import {ERC20Normalizer} from "src/ERC20Normalizer.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";

contract ERC20MintLibTest is Test {
    using stdJson for string;

    IERC20 public base;
    IERC20[] public tokens;
    address alice;
    address bob;
    ERC20Normalizer N;

    function setUp() public {
        tokens.push(loadToken("USDT"));
        tokens.push(loadToken("WMATIC"));

        alice = address(1111);
        vm.label(alice, "alice");
        bob = address(2222);
        vm.label(bob, "bob");

        N = new ERC20Normalizer();
    }

    function loadToken(string memory name) private returns (IERC20) {
        string memory json = vm.readFile("addresses.json");
        string memory profile = vm.envString("FOUNDRY_PROFILE");

        string memory key = string.concat("$.", name, ".", profile);
        address tokenAddress = json.readAddress(key);
        IERC20 token = IERC20(tokenAddress);
        vm.label(tokenAddress, name);
        return token;
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
