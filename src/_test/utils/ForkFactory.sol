// SPDX-License-Identifier:	AGPL-3.0
pragma solidity >=0.8.10;

import {GenericFork} from "mgv_test/lib/forks/Generic.sol";
import {PolygonFork} from "mgv_test/lib/forks/Polygon.sol";
import {MumbaiFork} from "mgv_test/lib/forks/Mumbai.sol";

library ForkFactory {
    function getFork() internal returns (GenericFork fork) {
        if (block.chainid == 80001) {
            fork = new MumbaiFork();
        } else if (block.chainid == 137) {
            fork = new PolygonFork();
        } else {
            revert("Unknown profile");
        }
    }
}
