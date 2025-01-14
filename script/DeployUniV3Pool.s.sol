// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import {Script, console2} from "forge-std/Script.sol";
import {ForkFactory} from "src/_test/utils/ForkFactory.sol";
import {GenericFork} from "@mgv/test/lib/forks/Generic.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {UniV3PriceLib} from "src/univ3/UniV3PriceLib.sol";
import {IERC20} from "@mgv/src/core/MgvLib.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";

contract DeployUniV3PoolScript is Script {
    GenericFork fork;

    address base;
    address quote;
    IUniswapV3Factory factory;

    function run() public {
        fork = ForkFactory.getFork();
        fork.setUp();

        innerRun({baseName: "WBTC", quoteName: "USDT", fees: 500});
    }

    function innerRun(
        string memory baseName,
        string memory quoteName,
        uint24 fees
    ) public {
        vm.startBroadcast();

        base = fork.get(baseName);
        require(base != address(0), "Base not found");

        quote = fork.get(quoteName);
        require(quote != address(0), "Quote not found");

        factory = IUniswapV3Factory(fork.get("UniV3 Factory"));
        require(address(factory) != address(0), "Factory not found");

        IUniswapV3Pool pool = IUniswapV3Pool(
            factory.getPool(base, quote, fees)
        );
        require(address(pool) == address(0), "Pool already exists");

        pool = IUniswapV3Pool(factory.createPool(base, quote, fees));
        console2.log("Pool created", address(pool));

        uint160 sqrtPriceX96 = UniV3PriceLib.priceToSqrtQ96(
            ud(25_000e18),
            IERC20(base),
            IERC20(quote)
        );
        pool.initialize(sqrtPriceX96);

        (uint160 sqrtPriceX96_, , , , , , ) = pool.slot0();
        require(
            sqrtPriceX96 == sqrtPriceX96_,
            "SqrtPriceX96 initialization mismatch"
        );
        console2.log("Pool initialized sqrtPriceX96", sqrtPriceX96_);
    }
}
