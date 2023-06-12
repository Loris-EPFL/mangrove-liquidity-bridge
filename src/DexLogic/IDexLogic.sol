// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.10;

import {UD60x18, ud} from "@prb/math/UD60x18.sol";

interface IDexLogic {
    function currentPrice(
        address base,
        address quote
    ) external view returns (UD60x18);

    function swap(
        address token_in,
        address token_out,
        UD60x18 amount_in,
        UD60x18 amount_out_min
    ) external returns (UD60x18 amount_out);
}
