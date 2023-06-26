// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import "@prb/math/Common.sol";
import {IERC20} from "mgv_src/MgvLib.sol";
import {Math64x64} from "src/math/Math64x64.sol";
import {MathLib} from "src/math/MathLib.sol";
import {TickMath} from "src/math/TickMath.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

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

    function priceToTick(
        UD60x18 price,
        UD60x18 denormFactor
    ) private pure returns (int24 tick) {
        uint160 p96 = MathLib.toQ96(price.mul(denormFactor).sqrt());
        console2.log("p96", MathLib.toUD60x18(p96).unwrap());
        tick = TickMath.getTickAtSqrtRatio(p96);
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
        console2.log("decimals0", decs0);
        console2.log("decimals1", decs1);

        bool baseIsToken0 = (base < quote);
        if (!baseIsToken0) {
            (priceLower, priceUpper) = (priceUpper, priceLower);
            priceLower = ud(1e18).div(priceLower);
            priceUpper = ud(1e18).div(priceUpper);
        }
        console2.log("priceLower", priceLower.unwrap());
        console2.log("priceUpper", priceUpper.unwrap());

        UD60x18 denormFactor;

        // TODO document this step
        if (decs0 > decs1) {
            denormFactor = ud(10 ** (decs0 - decs1 + 18));
        } else {
            denormFactor = ud(1e18) / ud(10 ** (decs1 - decs0 + 18));
        }
        console2.log("denormFactor", denormFactor.unwrap());

        tickLower = priceToTick(priceLower, denormFactor);
        tickLower = nearestUsableTick(tickLower, tickSpacing);

        tickUpper = priceToTick(priceUpper, denormFactor);
        tickUpper = nearestUsableTick(tickUpper, tickSpacing);
    }
}
