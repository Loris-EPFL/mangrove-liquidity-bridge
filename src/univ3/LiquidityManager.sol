// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import {IERC20} from "@mgv/src/core/MgvLib.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {LiquidityAmounts} from "./LiquidityAmounts.sol";
import {TickMath} from "src/math/TickMath.sol";
import {MathLib} from "src/math/MathLib.sol";
import {Math64x64} from "src/math/Math64x64.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {UniV3PriceLib} from "./UniV3PriceLib.sol";

/// @notice Helper contract to mint and swap on Uniswap V3
contract LiquidityManager {
    struct CallbackData {
        address token0;
        address token1;
        address payer;
    }

    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
        CallbackData memory extra = abi.decode(data, (CallbackData));

        IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
        IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
    }

    function mint(
        IUniswapV3Pool pool,
        address larry,
        int24 tickLeft,
        int24 tickRight,
        uint amount0,
        uint amount1
    ) public returns (uint amountRes0, uint amountRes1, uint128 liquidity) {
        console2.log("tickLeft", tickLeft);
        console2.log("tickRight", tickRight);

        bytes memory data = abi.encode(
            CallbackData({
                token0: pool.token0(),
                token1: pool.token1(),
                payer: larry
            })
        );

        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();

        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLeft),
            TickMath.getSqrtRatioAtTick(tickRight),
            amount0,
            amount1
        );
        (amountRes0, amountRes1) = pool.mint(
            larry,
            tickLeft,
            tickRight,
            liquidity,
            data
        );
    }

    function mint(
        IUniswapV3Pool pool,
        address larry,
        IERC20 base,
        IERC20 quote,
        UD60x18 priceLower,
        UD60x18 priceUpper,
        uint amountBase,
        uint amountQuote
    ) public returns (uint amountRes0, uint amountRes1, uint128 liquidity) {
        (int24 tickLower, int24 tickUpper) = UniV3PriceLib.GetTickRange(
            pool,
            base,
            quote,
            priceLower,
            priceUpper
        );

        (uint amount0, uint amount1) = base < quote
            ? (amountBase, amountQuote)
            : (amountQuote, amountBase);

        return mint(pool, larry, tickLower, tickUpper, amount0, amount1);
    }

    function uniswapV3SwapCallback(
        int256 amount0,
        int256 amount1,
        bytes calldata data
    ) public {
        CallbackData memory cbData = abi.decode(data, (CallbackData));

        if (amount0 > 0) {
            IERC20(cbData.token0).transferFrom(
                cbData.payer,
                msg.sender,
                uint256(amount0)
            );
        }

        if (amount1 > 0) {
            IERC20(cbData.token1).transferFrom(
                cbData.payer,
                msg.sender,
                uint256(amount1)
            );
        }
    }

    function swap(
        address payer,
        IUniswapV3Pool pool,
        address tokenIn,
        address tokenOut,
        uint amountIn
    ) public returns (uint amountOut) {
        bytes memory data = abi.encode(
            CallbackData({
                token0: pool.token0(),
                token1: pool.token1(),
                payer: payer
            })
        );

        bool zeroForOne = tokenIn < tokenOut; // TokenIn TokenOut

        (int256 amount0, int256 amount1) = pool.swap(
            payer,
            zeroForOne,
            MathLib.toInt(amountIn),
            zeroForOne
                ? TickMath.MIN_SQRT_RATIO + 1
                : TickMath.MAX_SQRT_RATIO - 1,
            data
        );
        // the output of swap represents the delta of the pool
        // we need to return the opposite of that to represent
        // the delta of the user
        amountOut = uint256(zeroForOne ? -amount1 : -amount0);
    }
}
