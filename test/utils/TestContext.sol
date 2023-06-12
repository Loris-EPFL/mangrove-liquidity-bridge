// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "forge-std/StdUtils.sol";
import {IERC20} from "mgv_src/MgvLib.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {ERC20Normalizer} from "src/ERC20Normalizer.sol";

contract TestContext is Test {
    using stdJson for string;

    ERC20Normalizer internal N;
    string public addressesJson;
    string public profile;

    constructor() {
        N = new ERC20Normalizer();
        addressesJson = vm.readFile("addresses.json");
        profile = vm.envString("FOUNDRY_PROFILE");
    }

    function dealNorm(IERC20 token, address to, UD60x18 amount) internal {
        uint amountDenorm = N.denormalize(token, amount.unwrap());
        deal(address(token), to, amountDenorm);
    }

    function balanceNorm(IERC20 token, address who) internal returns (uint) {
        return N.normalize(token, token.balanceOf(who));
    }

    function loadAddress(string memory name) internal returns (address) {
        string memory key = string.concat("$.", name, ".", profile);
        address addr = addressesJson.readAddress(key);
        vm.label(addr, name);
        return addr;
    }

    function loadToken(string memory name) internal returns (IERC20) {
        return IERC20(loadAddress(name));
    }
}
