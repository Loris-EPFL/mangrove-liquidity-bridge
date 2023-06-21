// SPDX-License-Identifier: UNLICENSED
pragma solidity <0.9.0;

import "../lib-0_7_6/v3-core/contracts/UniswapV3Factory.sol";
import "../lib-0_7_6/v3-core/contracts/UniswapV3Pool.sol";

contract UniswapV3PoolTest {
    UniswapV3Factory factory;
    UniswapV3Pool pool;

    bool transferInMintCallback = true;
    bool flashCallbackCalled = false;

    function setUp() public {
        factory = new UniswapV3Factory();
    }
}
