// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.10;

import {IERC20} from "mgv_src/MgvLib.sol";
import {IDexLogic} from "./IDexLogic.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {LiquidityManager} from "src/univ3/LiquidityManager.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {MathLib} from "src/math/MathLib.sol";
import {AccessControlled} from "mgv_src/strategies/utils/AccessControlled.sol";
import {ERC20Normalizer} from "src/ERC20Normalizer.sol";

contract DexUniV3 is LiquidityManager, IDexLogic, AccessControlled {
    IUniswapV3Pool private immutable pool;
    ERC20Normalizer private immutable N;

    constructor(address pool_, address admin) AccessControlled(admin) {
        pool = IUniswapV3Pool(pool_);
        N = new ERC20Normalizer();

        IERC20(pool.token0()).approve(pool_, type(uint256).max);
        IERC20(pool.token1()).approve(pool_, type(uint256).max);
    }

    /// @notice required by IDexLogic
    /// Transforms the sqrtPriceX96 to a price of 1 unit of base expressed in terms of unit of quotes
    /// Acts as a double denormalization (w.r.t. decimals) and ^2
    function currentPrice(
        address base,
        address quote
    ) public view override returns (UD60x18 price) {
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();

        UD60x18 sqrtPx = MathLib.toUD60x18(sqrtPriceX96);

        uint8 decs0 = IERC20(pool.token0()).decimals();
        uint8 decs1 = IERC20(pool.token1()).decimals();

        if (decs0 > decs1) {
            price = sqrtPx * sqrtPx * ud(10 ** (decs0 - decs1 + 18));
        } else {
            price = (sqrtPx * sqrtPx) / ud(10 ** (decs1 - decs0 + 18));
        }
        if (address(quote) < address(base)) {
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
        uint amount = swap(
            msg.sender,
            pool,
            token_in,
            token_out,
            N.denormalize(IERC20(token_in), amount_in.unwrap())
        );

        amount_out = ud(N.normalize(IERC20(token_out), amount));
        require(amount_out >= amount_out_min, "DexUniV3/swap/fail/slippage");
    }
}
