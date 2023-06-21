// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.10;

import {UD60x18, ud} from "@prb/math/UD60x18.sol";

library MathLib {
    function toQ96(UD60x18 q) internal pure returns (uint160) {
        uint intPart = (q.unwrap() / 1e18) << 96;
        uint fracPart = ((q.unwrap() % 1e18) << 96) / 1e18;
        return uint160(intPart + fracPart);
    }

    function toUD60x18(uint160 q) internal pure returns (UD60x18) {
        UD60x18 intPart = ud(uint(q >> 96) * 1e18);
        UD60x18 fracPart = ud(
            (uint(q & uint160(0xFFFFFFFFFFFFFFFFFFFFFFFF)) * 1e18) >> 96
        );
        return intPart + fracPart;
    }
}
