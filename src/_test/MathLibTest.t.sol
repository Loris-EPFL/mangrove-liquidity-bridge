// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

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

    function testX96ToUD() public pure {
        uint160 q96 = 1376472036138390016289905182008;
        UD60x18 ud1 = MathLib.toUD60x18(q96);
        console2.log("DexUniV3Test/testX96TOUD/ud", ud1.unwrap());
        console2.log(
            "DexUniV3Test/testX96TOUD/ud^2",
            ud1.pow(ud(2e18)).unwrap()
        );
    }
}
