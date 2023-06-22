// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import {TestContext} from "./utils/TestContext.sol";
import {IERC20} from "mgv_src/MgvLib.sol";
import {DexUniV3} from "src/DexLogic/DexUniV3.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {ERC20Normalizer} from "src/ERC20Normalizer.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "src/math/MathLib.sol";
import "src/math/TickMath.sol";
import "src/univ3/LiquidityAmounts.sol";

contract DexUniV3Test is TestContext {
    DexUniV3 dex;
    IERC20 base;
    IERC20 quote;
    uint24 fee;
    IUniswapV3Factory factory;
    address alice;
    address larry; // larry is the liquidity provider

    function setUp() public override {
        super.setUp();
        alice = address(1111);
        larry = address(2222);
    }

    function setDex(uint24 fee_) public {
        console2.log("DexUniV3Test/setUp/profile", profile);

        fee = fee_;

        address swapRouteur = loadAddress("UNIV3_ROUTER");
        vm.label(swapRouteur, "UniV3-routeur");

        factory = IUniswapV3Factory(loadAddress("UNIV3_FACTORY"));

        vm.label(address(factory), "UniV3-factory");
        dex = new DexUniV3(swapRouteur, address(factory), fee);
    }

    function checkOrCreatePool(
        UD60x18 currentPrice,
        UD60x18 quoteAmountDesired
    ) public {
        // check if pool exists
        bool baseIsToken0 = base < quote;
        address token0 = baseIsToken0 ? address(base) : address(quote);
        address token1 = baseIsToken0 ? address(quote) : address(base);
        if (!baseIsToken0) {
            currentPrice = ud(1e18).div(currentPrice);
        }

        address poolAddr = factory.getPool(token0, token1, fee);

        if (poolAddr == address(0)) {
            // create pool
            console2.log("DexUniV3Test/setUp/creating pool");
            poolAddr = factory.createPool(address(base), address(quote), fee);
        }

        // initialize pool and deposit
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddr);
        vm.label(poolAddr, "UniV3-pool");

        (uint currentPriceX96, , , , , , ) = pool.slot0();
        if (currentPriceX96 == 0) {
            pool.initialize(MathLib.toQ96(currentPrice));
        }

        UD60x18 baseAmountDesired = quoteAmountDesired / currentPrice;

        uint amount0Desired;
        uint amount1Desired;

        if (baseIsToken0) {
            amount0Desired = N.denormalize(base, baseAmountDesired.unwrap());
            deal(address(base), address(this), amount0Desired);
            amount1Desired = N.denormalize(quote, quoteAmountDesired.unwrap());
            deal(address(quote), address(this), amount1Desired);
        } else {
            amount0Desired = N.denormalize(quote, quoteAmountDesired.unwrap());
            deal(address(quote), address(this), amount0Desired);
            amount1Desired = N.denormalize(base, baseAmountDesired.unwrap());
            deal(address(base), address(this), amount1Desired);
        }

        // mint liquidity
        // compute the liquidity amount
        uint128 liquidity;
        {
            (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
            uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(-1000);
            uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(1000);

            liquidity = LiquidityAmounts.getLiquidityForAmounts(
                sqrtPriceX96,
                sqrtRatioAX96,
                sqrtRatioBX96,
                amount0Desired,
                amount1Desired
            );
        }

        base.approve(address(pool), type(uint256).max);
        quote.approve(address(pool), type(uint256).max);
        (uint amount0, uint amount1) = pool.mint(
            larry,
            -1000,
            1000,
            liquidity,
            ""
        );
    }

    //    function testWBTC_USD_midPrice_above_10_000() public {
    //base = loadToken("WBTC");
    //quote = loadToken("USDT");
    //setDex(3000);
    //checkOrCreatePool(ud(20000e18), ud(1e24));

    //UD60x18 midPrice = dex.currentPrice(address(base), address(quote));
    //console2.log(
    //"DexUniV3Test/testGetMidPrice/midPrice",
    //midPrice.unwrap() / 1e13
    //);
    //assertGt(midPrice.unwrap(), ud(10000).unwrap());
    //}

    function testUSDC_WBTC_midPrice_below_1() public {
        setDex(3000);

        base = loadToken("USDC");
        quote = loadToken("WBTC");
        UD60x18 midPrice = dex.currentPrice(address(base), address(quote));
        console2.log(
            "DexUniV3Test/testGetMidPrice/midPrice",
            midPrice.unwrap() / 1e13
        );
        assertLt(midPrice.unwrap(), ud(1e18).unwrap());
    }

    function testSellWBTC() public {
        setDex(3000);
        base = loadToken("WBTC");
        quote = loadToken("USDC");

        UD60x18 amount = ud(1e18);

        deal(address(base), alice, N.denormalize(base, amount.unwrap()));

        vm.prank(alice);
        //base.approve(address(dex), N.denormalize(base, amount.unwrap()));
        base.approve(address(dex), type(uint256).max);
        vm.prank(alice);
        dex.swap(address(base), address(quote), amount, ud(0));
    }
}
