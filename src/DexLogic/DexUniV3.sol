// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import {IERC20} from "mgv_src/MgvLib.sol";
import {IDexLogic} from "./IDexLogic.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {AccessControlled} from "mgv_src/strategies/utils/AccessControlled.sol";
import {ERC20Normalizer} from "src/ERC20Normalizer.sol";

contract DexUniV3 is IDexLogic, AccessControlled {
    ISwapRouter private swapRouter;
    IUniswapV3Factory private factory;
    ERC20Normalizer private immutable N;
    uint24 private fee;

    constructor(
        address swapRouter_,
        address factory_,
        uint24 fee_
    ) AccessControlled(msg.sender) {
        swapRouter = ISwapRouter(swapRouter_);
        factory = IUniswapV3Factory(factory_);
        fee = fee_;
        N = new ERC20Normalizer();
    }

    /// @notice Set the fee for the Uniswap pool to use
    function setFee(uint24 fee_) external onlyAdmin {
        fee = fee_;
    }

    /// @notice utility function to convert uint160 (for sqrtPrice96) to UD60x18
    function toUD60x18(uint160 q) internal pure returns (UD60x18) {
        UD60x18 intPart = ud(uint(q >> 96) * 1e18);
        UD60x18 fracPart = ud(
            (uint(q & uint160(0xFFFFFFFFFFFFFFFFFFFFFFFF)) * 1e18) >> 96
        );
        return intPart + fracPart;
    }

    function currentPrice(
        address base,
        address quote
    ) public view override returns (UD60x18 price) {
        IUniswapV3Pool pool = IUniswapV3Pool(
            factory.getPool(address(base), address(quote), fee)
        );

        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();

        UD60x18 sqrtPx = toUD60x18(sqrtPriceX96);

        uint8 decs0 = IERC20(pool.token0()).decimals();
        uint8 decs1 = IERC20(pool.token1()).decimals();

        if (decs0 > decs1) {
            price = sqrtPx * sqrtPx * ud(10 ** (decs0 - decs1 + 18));
        } else {
            price = (sqrtPx * sqrtPx) / ud(10 ** (decs1 - decs0 + 18));
        }
        if (base != pool.token0()) {
            price = ud(1e18) / price;
        }
    }

    // https://docs.uniswap.org/contracts/v3/reference/core/UniswapV3Pool#swap
    function swap(
        address token_in,
        address token_out,
        UD60x18 amount_in,
        UD60x18 amount_out_min
    ) public override returns (UD60x18 amount_out) {
        IERC20(token_in).transferFrom(
            msg.sender,
            address(this),
            N.denormalize(IERC20(token_in), amount_in.unwrap())
        );

        IERC20(token_in).approve(address(swapRouter), type(uint256).max);

        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: token_in,
                tokenOut: token_out,
                fee: fee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: N.denormalize(IERC20(token_in), amount_in.unwrap()),
                amountOutMinimum: N.denormalize(
                    IERC20(token_out),
                    amount_out_min.unwrap()
                ),
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        amount_out = ud(swapRouter.exactInputSingle(params));
    }
}
