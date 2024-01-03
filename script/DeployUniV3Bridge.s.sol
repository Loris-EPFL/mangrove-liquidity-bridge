// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import {Script, console2} from "forge-std/Script.sol";
import {ForkFactory} from "src/_test/utils/ForkFactory.sol";
import {IERC20} from "@mgv/src/core/MgvLib.sol";
import {GenericFork} from "@mgv/test/lib/forks/Generic.sol";
import {IMangrove} from "@mgv/src/IMangrove.sol";
import {MgvReader, toOLKey, Market} from "@mgv/src/periphery/MgvReader.sol";
import {MgvLib, OLKey} from "@mgv/src/core/MgvLib.sol";
import {TickLib} from "@mgv/lib/core/TickLib.sol";
import {Local} from "@mgv/src/preprocessed/Local.post.sol";
import {IDexLogic} from "src/DexLogic/IDexLogic.sol";
import {DexUniV3} from "src/DexLogic/DexUniV3.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ERC20Normalizer} from "src/ERC20Normalizer.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {LiquidityBridge} from "src/LiquidityBridge.sol";

contract DeployUniV3BridgeScript is Script {
    GenericFork fork;

    IMangrove mgv;
    MgvReader reader;

    IERC20 public base;
    IERC20 public quote;
    uint24 public fee = 100;
    uint8 public tickSpacing = 1;

    address chief;

    address uniV3PoolAddress;
    IDexLogic public dex;

    LiquidityBridge bridge;
    UD60x18 quoteAmount = ud(100_000e18);
    UD60x18 spreadRatio = ud(100020e13); // 1% 1.01

    ERC20Normalizer N = new ERC20Normalizer();

    function setUp() public {
        fork = ForkFactory.getFork();
        fork.setUp();

        chief = vm.envAddress("CHIEF");

        setUpTokens();

        setUpMangrove();

        setUpDex();
    }

    function run() public {
        //setUp();
        check();

        createDexLogic();

        createBridge();
    }

    function deployDexLogic() public {
        check();

        vm.startBroadcast();
        createDexLogic();
        vm.stopBroadcast();
    }

    function deployBridge() public {
        check();

        // read from .env
        loadDexLogic("DEXLOGIC");

        vm.startBroadcast();
        createBridge();
        vm.stopBroadcast();
    }

    function setUpTokens() public {
        // setupping tokens
        base = IERC20(fork.get("USDC"));
        console2.log("Base token", address(base));
        console2.log("Base token symbol", base.symbol());
        console2.log("Base token decimals", base.decimals());

        quote = IERC20(fork.get("USDT"));
        console2.log("Quote token", address(quote));
        console2.log("Quote token symbol", quote.symbol());
        console2.log("Quote token decimals", quote.decimals());
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
            "Factory address not found in addresses.json"
        );

        IUniswapV3Factory factory = IUniswapV3Factory(factoryAddress);
        // get or create pool
        uniV3PoolAddress = factory.getPool(address(base), address(quote), fee);
        require(
            uniV3PoolAddress != address(0),
            "Pool address not found for pair and fees"
        );

        console2.log("UniV3 Pool :", uniV3PoolAddress);

        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(uniV3PoolAddress)
            .slot0();
        require(sqrtPriceX96 > 0, "UniV3 Pool not initialized");
    }

    function check() public {
        checkMangrove();

        checkDex();
    }
    
    function checkMangrove() public {
        Local localAsk;
        Local localBid;

        OLKey memory olKeyB = toOLKey(Market({
            tkn0: address(base), 
            tkn1: address(quote), 
            tickSpacing: tickSpacing
        }));

        OLKey memory olKeyQ = toOLKey(Market({
            tkn0: address(quote), 
            tkn1: address(base), 
            tickSpacing: tickSpacing
        }));

        localAsk = mgv.local(olKeyB);
        localBid = mgv.local(olKeyQ);

        require(localAsk.active(), "Local ASK not active");
        require(localBid.active(), "Local BID not active");

        // mangrove OB exists + output KPIs
        // - OB active on both sides (ASK & BID)
        // -
        // kpi 1 : density, impact on quoteAmount
        Local local;
        local = mgv.local(olKeyB);
        /*
        console2.log("Local ASK density", local.density());
        console2.log("Local ASK active", local.active());
        console2.log("Local ASK fee", local.fee());
        console2.log("Local ASK offer.gas_base", local.offer_gasbase());

        local = mgv.local(olKeyQ);
        console2.log("Local BID density", local.density());
        console2.log("Local BID active", local.active());
        console2.log("Local BID fee", local.fee());
        console2.log("Local BID offer.gas_base", local.offer_gasbase());
        */
        /*
        uint volume;
        UD60x18 volumeNorm;
        
        volume = reader.minVolume(address(base), address(quote), 500_000);
        volumeNorm = ud(N.normalize(base, volume));
        console2.log("Min ASK volume", volumeNorm.unwrap());

        volume = reader.minVolume(address(quote), address(base), 500_000);
        volumeNorm = ud(N.normalize(quote, volume));
        console2.log("Min BID volume", volumeNorm.unwrap());
        */
    }

    function checkDex() public view {
        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(uniV3PoolAddress)
            .slot0();
        require(sqrtPriceX96 > 0, "UniV3 Pool not initialized");
    }

    function checkDexLogic() public view {
        require(address(dex) != address(0), "DexLogic not found");
        require(
            dex.currentPrice(address(base), address(quote)).gt(ud(0)),
            "DexLogic not initialized"
        );
    }

    function loadDexLogic(string memory dexLogicName) public {
        dex = IDexLogic(vm.envAddress(dexLogicName));
        checkDexLogic();
    }

    function createDexLogic() public {
        dex = new DexUniV3(uniV3PoolAddress, chief);
        checkDexLogic();
    }

    function createBridge() public {
        bridge = new LiquidityBridge(
            mgv,
            base,
            quote,
            quoteAmount,
            spreadRatio,
            address(dex),
            chief
        );
    }
}
