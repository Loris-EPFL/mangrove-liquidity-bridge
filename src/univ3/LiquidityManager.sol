// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "mgv_src/MgvLib.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {LiquidityAmounts} from "./LiquidityAmounts.sol";
import {TickMath} from "src/math/TickMath.sol";

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
}
