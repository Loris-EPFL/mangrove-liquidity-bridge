// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import {IERC20} from "mgv_src/MgvLib.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {LiquidityAmounts} from "./LiquidityAmounts.sol";
import {TickMath} from "src/math/TickMath.sol";
import {MathLib} from "src/math/MathLib.sol";

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
    ) public {
        bytes memory data = abi.encode(
            CallbackData({
                token0: pool.token0(),
                token1: pool.token1(),
                payer: payer
            })
        );

        bool zeroForOne = tokenIn < tokenOut; // TokenIn TokenOut

        pool.swap(
            payer,
            zeroForOne,
            zeroForOne ? MathLib.toInt(amountIn) : -MathLib.toInt(amountIn),
            zeroForOne
                ? TickMath.MIN_SQRT_RATIO + 1
                : TickMath.MAX_SQRT_RATIO - 1,
            data
        );
    }
}
