// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {TestContext} from "./utils/TestContext.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "mgv_src/MgvLib.sol";
import {MathLib} from "src/utils/MathLib.sol";
import {TickMath} from "src/utils/TickMath.sol";
import {LiquidityAmounts} from "src/utils/LiquidityAmounts.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {ERC20Normalizer} from "src/ERC20Normalizer.sol";

contract UniV3PoolTest is TestContext {
    IERC20 base;
    IERC20 quote;
    bool baseIsToken0;

    IERC20 token0;
    IERC20 token1;

    uint24 fee = 3000;

    UD60x18 currentPrice = ud(25_000e18);
    UD60x18 tokenPrice;

    address alice;
    address larry;

    IUniswapV3Factory factory;
    IUniswapV3Pool pool;

    function setUp() public {
        N = new ERC20Normalizer();
        vm.label(address(N), "ERC20Normalizer");

        console2.log("UniV3PoolTest/setUp/profile", profile);
        alice = address(1111);
        vm.label(alice, "alice");

        larry = address(2222);
        vm.label(larry, "larry");

        base = loadToken("WBTC");
        quote = loadToken("USDC");

        // adjusting inputs for token0/token1
        if (base < quote) {
            baseIsToken0 = true;
            tokenPrice = currentPrice;
        } else {
            baseIsToken0 = false;
            tokenPrice = ud(1e18).div(currentPrice);
        }

        token0 = baseIsToken0 ? base : quote;
        token1 = baseIsToken0 ? quote : base;

        getOrCreatePool();

        setBalancesAndApprovals();
    }

    function getOrCreatePool() public {
        factory = IUniswapV3Factory(loadAddress("UNIV3_FACTORY"));
        vm.label(address(factory), "UniV3-factory");

        address poolAddress = factory.getPool(
            address(token0),
            address(token1),
            fee
        );

        if (poolAddress == address(0)) {
            console2.log("UniV3PoolTest/getOrCreatePool/creating pool");
            poolAddress = factory.createPool(
                address(token0),
                address(token1),
                fee
            );
        }
        vm.label(poolAddress, "UniV3-pool");
        pool = IUniswapV3Pool(poolAddress);

        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        if (sqrtPriceX96 == 0) {
            console2.log("UniV3PoolTest/getOrCreatePool/initializing pool");
            pool.initialize(MathLib.toQ96(tokenPrice.sqrt()));
        } else {
            tokenPrice = MathLib.toUD60x18(sqrtPriceX96).pow(ud(2e18));
        }
    }

    /// @notice deal and approve for one token
    /// currentPrice should be pertinent (so this function should be called after getOrCreatePool)
    function setBalanceAndApproval(
        IERC20 token,
        address account,
        UD60x18 amount
    ) internal {
        deal(address(token), account, N.denormalize(token, amount.unwrap()));
        vm.prank(account);
        token.approve(address(this), type(uint256).max);
    }

    /// @notice deal and approve for base and quote, alice and larry
    /// currentPrice should be pertinent (so this function should be
    /// called after getOrCreatePool)
    function setBalancesAndApprovals() public {
        UD60x18 baseAmount = ud(100e18);

        UD60x18 token0Amount = baseIsToken0
            ? baseAmount
            : baseAmount.mul(currentPrice);
        UD60x18 token1Amount = baseIsToken0
            ? baseAmount.mul(currentPrice)
            : baseAmount;

        // deal and approve for alice
        setBalanceAndApproval(token0, alice, token0Amount);
        setBalanceAndApproval(token1, alice, token1Amount);
        console2.log(
            "UniV3PoolTest/setBalancesAndApprovals/alice (t0/t1)",
            token0.balanceOf(alice),
            token1.balanceOf(alice)
        );

        // deal and approve for larry
        setBalanceAndApproval(token0, larry, token0Amount);
        setBalanceAndApproval(token1, larry, token1Amount);
    }

    function testUniV3Pool() public {
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        UD60x18 price = MathLib.toUD60x18(sqrtPriceX96).pow(ud(2e18));
    }

    struct CallbackData {
        address token0;
        address token1;
        address payer;
    }

    function testMintLiquidityOnUniV3Pool() public {
        // compute the liquidity amount
        uint128 liquidity;
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(-1000);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(1000);

        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            token0.balanceOf(larry) / 2,
            token1.balanceOf(larry) / 2
        );
        console2.log(
            "UniV3PoolTest/testMintLiquidityOnUniV3Pool/liquidity",
            liquidity
        );

        bytes memory data = abi.encode(
            CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: larry
            })
        );

        (uint amount0, uint amount1) = pool.mint(
            larry,
            -1000,
            1000,
            liquidity,
            data
        );
    }
}
