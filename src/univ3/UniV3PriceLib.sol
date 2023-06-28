// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import "@prb/math/Common.sol";
import {IERC20} from "mgv_src/MgvLib.sol";
import {Math64x64} from "src/math/Math64x64.sol";
import {MathLib} from "src/math/MathLib.sol";
import {TickMath} from "src/math/TickMath.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

/// @notice Helper contract to compute liquidity and transform prices
library UniV3PriceLib {
    function nearestUsableTick(
        int24 tick_,
        int24 tickSpacing
    ) internal pure returns (int24 result) {
        result =
            int24(
                Math64x64.divRound(int128(tick_), int128(int24(tickSpacing)))
            ) *
            int24(tickSpacing);

        if (result < TickMath.MIN_TICK) {
            result += int24(tickSpacing);
        } else if (result > TickMath.MAX_TICK) {
            result -= int24(tickSpacing);
        }
    }

    function priceToSqrtQ96(
        UD60x18 price,
        uint8 decs0,
        uint8 decs1
    ) public pure returns (uint160 sqrtPriceX96) {
        UD60x18 denormFactor;
        if (decs0 < decs1) {
            denormFactor = ud(10 ** (18 + decs1 - decs0));
        } else {
            denormFactor = ud(1e18).div(ud(10 ** (18 + decs0 - decs1)));
        }
        sqrtPriceX96 = MathLib.toQ96(price.mul(denormFactor).sqrt());
    }

    function GetTickRange(
        IUniswapV3Pool pool,
        IERC20 base,
        IERC20 quote,
        UD60x18 priceLower,
        UD60x18 priceUpper
    ) public view returns (int24 tickLower, int24 tickUpper) {
        uint8 decs0 = IERC20(pool.token0()).decimals();
        uint8 decs1 = IERC20(pool.token1()).decimals();
        int24 tickSpacing = pool.tickSpacing();

        bool baseIsToken0 = (base < quote);
        if (!baseIsToken0) {
            (priceLower, priceUpper) = (priceUpper, priceLower);
            priceLower = ud(1e18).div(priceLower);
            priceUpper = ud(1e18).div(priceUpper);
        }

        uint160 sqrtPX96Lower = priceToSqrtQ96(priceLower, decs0, decs1);
        uint160 sqrtPX96Upper = priceToSqrtQ96(priceUpper, decs0, decs1);

        tickLower = TickMath.getTickAtSqrtRatio(sqrtPX96Lower);
        tickLower = nearestUsableTick(tickLower, tickSpacing);

        tickUpper = TickMath.getTickAtSqrtRatio(sqrtPX96Upper);
        tickUpper = nearestUsableTick(tickUpper, tickSpacing);
    }
}
