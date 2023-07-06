// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import {Script, console2} from "forge-std/Script.sol";
import {ForkFactory} from "src/_test/utils/ForkFactory.sol";
import {IERC20} from "mgv_src/MgvLib.sol";
import {GenericFork} from "mgv_test/lib/forks/Generic.sol";
import {IMangrove} from "mgv_src/IMangrove.sol";
import {MgvReader} from "mgv_src/periphery/MgvReader.sol";
import {MgvStructs} from "mgv_src/MgvLib.sol";
import {IDexLogic} from "src/DexLogic/IDexLogic.sol";
import {DexUniV3} from "src/DexLogic/DexUniV3.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ERC20Normalizer} from "src/ERC20Normalizer.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {LiquidityBridge} from "src/LiquidityBridge.sol";

contract DeployUniV3BridgeCheck is Script {
    GenericFork fork;

    IMangrove mgv;
    MgvReader reader;

    IERC20 public base;
    IERC20 public quote;
    uint24 public fee = 500;

    IDexLogic public dex;

    LiquidityBridge bridge;
    UD60x18 quoteAmount = ud(1_000e18);
    UD60x18 spreadRatio = ud(1010e15);

    ERC20Normalizer N = new ERC20Normalizer();

    function run() public {
        setUp();

        check();

        vm.startBroadcast();
        deployBridge();
    }

    function setUp() public {
        fork = ForkFactory.getFork();
        fork.setUp();

        setUpTokens();

        setUpMangrove();

        setUpDex();
    }

    function setUpTokens() public {
        // setupping tokens
        base = IERC20(fork.get("WBTC"));
        quote = IERC20(fork.get("USDT"));
    }

    function setUpMangrove() public {
        // setupping mangrove & reader
        mgv = IMangrove(fork.get("Mangrove"));
        reader = new MgvReader(address(mgv));
    }

    function setUpDex() public {
        // setupping univ3 dex
        address factoryAddress = fork.get("UniV3 Factory");
        require(
            factoryAddress != address(0),
            "Factory address not found in env"
        );

        IUniswapV3Factory factory = IUniswapV3Factory(factoryAddress);
        // get or create pool
        address poolAddress = factory.getPool(
            address(base),
            address(quote),
            fee
        );
        require(
            poolAddress != address(0),
            "Pool address not found for pair and fees"
        );

        console2.log("UniV3 Pool :", poolAddress);

        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(poolAddress)
            .slot0();
        require(sqrtPriceX96 > 0, "UniV3 Pool not initialized");

        dex = new DexUniV3(poolAddress);
    }

    function check() public {
        checkMangrove();

        checkDex();
    }

    function checkMangrove() public {
        MgvStructs.LocalPacked localAsk;
        MgvStructs.LocalPacked localBid;

        localAsk = reader.local(address(base), address(quote));
        localBid = reader.local(address(quote), address(base));

        require(localAsk.active(), "Local ASK not active");
        require(localBid.active(), "Local BID not active");

        // mangrove OB exists + output KPIs
        // - OB active on both sides (ASK & BID)
        // -
        // kpi 1 : density, impact on quoteAmount
        MgvStructs.LocalPacked local;
        local = reader.local(address(base), address(quote));
        console2.log("Local density", local.density());
        console2.log("Local active", local.active());
        console2.log("Local fee", local.fee());
        console2.log("Local offer.gas_base", local.offer_gasbase());

        local = reader.local(address(quote), address(base));
        console2.log("Local density", local.density());
        console2.log("Local active", local.active());
        console2.log("Local fee", local.fee());
        console2.log("Local offer.gas_base", local.offer_gasbase());

        uint volume;
        UD60x18 volumeNorm;

        volume = reader.minVolume(address(base), address(quote), 500_000);
        volumeNorm = ud(N.normalize(base, volume));
        console2.log("Min ASK volume", volumeNorm.unwrap());

        volume = reader.minVolume(address(quote), address(base), 500_000);
        volumeNorm = ud(N.normalize(quote, volume));
        console2.log("Min BID volume", volumeNorm.unwrap());
    }

    function checkDex() public view {
        // target dex exists + output KPIs
        // kpi 1 : current midPrice
        // kpi 2 : slippage for quoteAmount
        UD60x18 midPrice = dex.currentPrice(address(base), address(quote));
        console2.log("Dex midPrice", midPrice.unwrap());
    }

    function deployBridge() public {
        bridge = new LiquidityBridge(
            mgv,
            base,
            quote,
            quoteAmount,
            spreadRatio,
            address(dex),
            fork.get("CHIEF")
        );
    }
}
