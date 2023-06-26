// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import {TestContext} from "./TestContext.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "mgv_src/MgvLib.sol";
import {MathLib} from "src/math/MathLib.sol";
import {TickMath} from "src/math/TickMath.sol";
import {LiquidityManager} from "src/univ3/LiquidityManager.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {ERC20Normalizer} from "src/ERC20Normalizer.sol";

contract UniV3PoolBuilder is Test, LiquidityManager {
    IERC20 base;
    IERC20 quote;
    bool baseIsToken0;

    IERC20 token0;
    IERC20 token1;

    uint24 fee;

    IUniswapV3Factory public factory;
    IUniswapV3Pool public pool;

    ERC20Normalizer N;

    constructor(IERC20 base_, IERC20 quote_, uint24 fee_) {
        N = new ERC20Normalizer();

        base = base_;
        quote = quote_;
        fee = fee_;

        baseIsToken0 = base < quote;

        token0 = baseIsToken0 ? base : quote;
        token1 = baseIsToken0 ? quote : base;

        createPool();
    }

    function createPool() internal {
        // factory is loaded from previously deployed contract
        // (see src-0_7_6/build_to_deploy_artefact.sol)
        factory = IUniswapV3Factory(
            deployCode("UniswapV3Factory.sol:UniswapV3Factory")
        );
        vm.label(address(factory), "UniV3-factory");

        address poolAddress = factory.createPool(
            address(token0),
            address(token1),
            fee
        );

        vm.label(
            poolAddress,
            string.concat("UniV3", token0.symbol(), "-", token1.symbol())
        );
        pool = IUniswapV3Pool(poolAddress);
    }

    function initiateLiquidity(
        address larry,
        UD60x18 currentPrice,
        UD60x18 quoteAmount,
        UD60x18 priceLower,
        UD60x18 priceUpper
    ) public returns (uint amount0, uint amount1) {
        UD60x18 tokenPrice;

        // adjusting price for token0/token1
        if (base < quote) {
            tokenPrice = currentPrice;
        } else {
            tokenPrice = ud(1e18).div(currentPrice);
        }

        console2.log(
            "UniV3PoolBuilder/initiateLiquidity/initializing with tokenPrice:",
            tokenPrice.unwrap()
        );
        pool.initialize(MathLib.toQ96(tokenPrice.sqrt()));

        // deal tokens and approve for larry
        UD60x18 baseAmount = quoteAmount.div(currentPrice);

        uint baseAmountDenorm = N.denormalize(base, baseAmount.unwrap());
        uint quoteAmountDenorm = N.denormalize(quote, quoteAmount.unwrap());

        deal(address(base), larry, baseAmountDenorm * 2);
        deal(address(quote), larry, quoteAmountDenorm * 2);
        console2.log("Larry base balance", base.balanceOf(larry));
        console2.log("Larry quote balance", quote.balanceOf(larry));

        vm.startPrank(larry);
        base.approve(address(this), type(uint256).max);
        quote.approve(address(this), type(uint256).max);
        vm.stopPrank();

        // mint liquidity
        (amount0, amount1, ) = mint(
            pool,
            larry,
            base,
            quote,
            priceLower,
            priceUpper,
            baseAmountDenorm,
            quoteAmountDenorm
        );
        console2.log("UniV3PoolBuilder/initiateLiquidity/amount0", amount0);
        console2.log("UniV3PoolBuilder/initiateLiquidity/amount1", amount1);
    }
}