// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.10;

import {UD60x18, ud} from "@prb/math/UD60x18.sol";

interface IDexLogic {
    /// @notice price of 1 unit of base expressed in terms of unit of quotes
    function currentPrice(
        address base,
        address quote
    ) external view returns (UD60x18);

    /// @notice swap `amount_in` of `token_in` for `token_out`
    /// @param token_in address of token to swap in the dex
    /// @param token_out address of token to swap out of the dex
    /// @param amount_in normalized quantity of token_in to swap
    /// @param amount_out_min minimum normalized quantity of token_out to receive (slippage control)
    /// @return amount_out normalized quantity of token_out received
    function swap(
        address token_in,
        address token_out,
        UD60x18 amount_in,
        UD60x18 amount_out_min
    ) external returns (UD60x18 amount_out);
}
