// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import {Test2} from "mgv_lib/Test2.sol";
import {ForkFactory} from "./utils/ForkFactory.sol";
import {GenericFork} from "mgv_test/lib/forks/Generic.sol";
import "forge-std/StdJson.sol";
import "forge-std/StdUtils.sol";
import {IERC20} from "mgv_src/MgvLib.sol";
import {ERC20Normalizer} from "src/ERC20Normalizer.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {DexFix} from "src/DexLogic/DexFix.sol";

contract DexFixTest is Test2 {
    GenericFork fork;

    DexFix public dex;

    IERC20 public base;
    IERC20 public quote;

    address base_owner;
    address quote_owner;

    ERC20Normalizer N;

    address alice;

    function setUp() public {
        fork = ForkFactory.getFork();
        fork.setUp();

        N = new ERC20Normalizer();

        base = IERC20(fork.get("WMATIC"));
        quote = IERC20(fork.get("USDT"));

        dex = new DexFix(address(base), address(quote));

        alice = freshAddress("alice");
    }

    function testMintImpersonating() public {
        UD60x18 amount = ud(1e18);
        uint amountDenorm = N.denormalize(base, amount.unwrap());

        deal(address(base), address(dex), amountDenorm);
        assertEq(
            N.normalize(base, base.balanceOf(address(dex))),
            amount.unwrap()
        );

        amount = ud(1000e18);
        amountDenorm = N.denormalize(quote, amount.unwrap());
        deal(address(quote), address(dex), amountDenorm);
        assertEq(
            N.normalize(quote, quote.balanceOf(address(dex))),
            amount.unwrap()
        );
    }

    function testGetMidPrice() public {
        uint price_uint = 1000e18;
        UD60x18 price_ud = ud(price_uint);
        dex.setPrice(price_ud);
        assertEq(
            dex.currentPrice(address(base), address(quote)).unwrap(),
            price_ud.unwrap()
        );
    }

    function testUnsupportedTokens() public {
        vm.expectRevert();
        dex.swap(address(0), address(quote), ud(1), ud(1));

        vm.expectRevert();
        dex.swap(address(base), address(0), ud(1), ud(1));
    }

    function testSwap() public {
        UD60x18 init_base_amount = ud(1e18);
        UD60x18 traded_base_amount = init_base_amount.div(ud(4e18));
        UD60x18 init_quote_amount = ud(1000e18);
        UD60x18 price = ud(1000e18);

        deal(
            address(base),
            address(alice),
            N.denormalize(base, init_base_amount.unwrap())
        );
        deal(
            address(quote),
            address(dex),
            N.denormalize(quote, init_quote_amount.unwrap())
        );

        console2.log("Alice balance (base): ", base.balanceOf(address(alice)));
        console2.log(
            "Liq. Reserve balance (quote): ",
            quote.balanceOf(address(dex))
        );

        dex.setPrice(price);

        vm.startPrank(alice);

        base.approve(
            address(dex),
            N.denormalize(base, traded_base_amount.unwrap())
        );
        dex.swap(address(base), address(quote), traded_base_amount, ud(0));

        assertEq(
            N.normalize(base, base.balanceOf(alice)),
            (init_base_amount - traded_base_amount).unwrap()
        );
        assertEq(
            N.normalize(quote, quote.balanceOf(alice)),
            traded_base_amount.mul(price).unwrap()
        );
        assertEq(
            N.normalize(base, base.balanceOf(address(dex))),
            traded_base_amount.unwrap()
        );

        base.approve(
            address(dex),
            N.denormalize(base, traded_base_amount.unwrap())
        );

        // should revert because of price slippage
        vm.expectRevert();
        dex.swap(
            address(base),
            address(quote),
            traded_base_amount,
            traded_base_amount.mul(price) + ud(1)
        );
    }
}
