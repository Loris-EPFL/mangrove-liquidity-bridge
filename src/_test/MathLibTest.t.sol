// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/math/MathLib.sol";

contract MathLibTest is Test {
    function testConversionX96AndUD() public {
        UD60x18 ud1 = ud(1e18);
        uint160 x961 = MathLib.toQ96(ud1);
        UD60x18 ud2 = MathLib.toUD60x18(x961);
        uint x962 = MathLib.toQ96(ud2);
        console2.log("DexUniV3Test/testConversionX96AndUD/ud1", ud1.unwrap());
        console2.log("DexUniV3Test/testConversionX96AndUD/x961", x961);
        console2.log("DexUniV3Test/testConversionX96AndUD/ud2", ud2.unwrap());
        assertEq(ud1.unwrap(), ud2.unwrap());
        assertEq(x961, x962);
    }
}
